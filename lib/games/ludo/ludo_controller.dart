import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'ludo_bot.dart';
import 'ludo_model.dart';
import 'ludo_progress_repository.dart';

enum LudoBotAction { rolling, choosingToken }

class LudoController extends ChangeNotifier {
  factory LudoController({
    required int playerCount,
    List<MatchParticipant>? participants,
    LudoDiceRoller? diceRoller,
    LudoModel? model,
    Duration movementStepDuration = const Duration(milliseconds: 150),
    Duration? botRollDelay,
    Duration? botMoveDelay,
    Random? random,
    LudoBot? bot,
    MatchSession? session,
    LudoProgressRepository? repository,
  }) {
    final resolvedRandom = random ?? Random();
    final resolvedModel =
        model ??
        LudoModel(
          playerCount: playerCount,
          diceRoller: diceRoller ?? _randomRoll,
        );
    return LudoController._(
      playerCount: playerCount,
      model: resolvedModel,
      movementStepDuration: movementStepDuration,
      participants: participants ?? session?.options.participants,
      botRollDelay: botRollDelay,
      botMoveDelay: botMoveDelay,
      random: resolvedRandom,
      bot: bot ?? LudoBot(random: resolvedRandom),
      session: session,
      repository: repository,
    );
  }

  LudoController._({
    required int playerCount,
    required this.model,
    required this.movementStepDuration,
    required List<MatchParticipant>? participants,
    required this.botRollDelay,
    required this.botMoveDelay,
    required Random random,
    required LudoBot bot,
    required this.session,
    required this.repository,
  }) : _displayProgress = [
         for (final tokens in model.tokenProgress) List<int>.of(tokens),
       ],
       _participants = participants == null
           ? List<MatchParticipant?>.filled(playerCount, null)
           : List<MatchParticipant?>.of(participants),
       _random = random,
       _bot = bot {
    if (model.playerCount != playerCount) {
      throw ArgumentError.value(
        playerCount,
        'playerCount',
        'Must match the supplied model',
      );
    }
    if (_participants.length != playerCount) {
      throw ArgumentError.value(
        _participants.length,
        'participants',
        'Must contain one descriptor per participant',
      );
    }
    if (_participants.every((participant) => participant?.isBot ?? false)) {
      throw ArgumentError('A local Ludo match requires at least one human');
    }
    _observedRound = session?.round ?? 0;
    _observedPhase = session?.phase ?? MatchPhase.playing;
    _hasStartedRound = _observedRound > 0;
    session?.addListener(_syncSession);
    if (_acceptsTurns) _scheduleBotAction();
  }

  final LudoModel model;
  final Duration movementStepDuration;
  final Duration? botRollDelay;
  final Duration? botMoveDelay;
  final List<List<int>> _displayProgress;
  final List<MatchParticipant?> _participants;
  final Random _random;
  final LudoBot _bot;
  final MatchSession? session;
  final LudoProgressRepository? repository;

  List<List<int>> get displayProgress => List.unmodifiable(
    _displayProgress.map((tokens) => List<int>.unmodifiable(tokens)),
  );

  bool get isAnimating => _movementTimer != null || _pendingProgress.isNotEmpty;
  bool get isBotTurn =>
      !model.isFinished && (_participants[model.currentPlayer]?.isBot ?? false);
  bool get isBotThinking => _botTimer?.isActive ?? false;
  LudoBotAction? get pendingBotAction => _pendingBotAction;
  bool get canRoll =>
      !_disposed &&
      _acceptsTurns &&
      !isAnimating &&
      !isBotTurn &&
      !isBotThinking &&
      model.phase == LudoTurnPhase.awaitingRoll;
  bool get canChooseToken =>
      !_disposed &&
      _acceptsTurns &&
      !isAnimating &&
      !isBotTurn &&
      !isBotThinking &&
      model.phase == LudoTurnPhase.awaitingMove;
  List<int> get legalTokenIndexes =>
      canChooseToken ? model.legalTokenIndexes : const [];

  int? _animationPlayer;
  int? get animationPlayer => _animationPlayer;
  int? _animationToken;
  int? get animationToken => _animationToken;
  final List<int> _pendingProgress = [];
  Timer? _movementTimer;
  Timer? _botTimer;
  LudoBotAction? _pendingBotAction;
  int _observedRound = 0;
  MatchPhase _observedPhase = MatchPhase.playing;
  bool _hasStartedRound = false;
  bool _disposed = false;

  bool get _acceptsTurns =>
      session == null || session!.phase == MatchPhase.playing;

  LudoRoll? roll() {
    if (!canRoll) return null;
    return _performRoll();
  }

  LudoRoll _performRoll() {
    final result = model.rollDice();
    _saveProgress();
    notifyListeners();
    if (isBotTurn) _scheduleBotAction();
    return result;
  }

  LudoMoveResult chooseToken(int tokenIndex) {
    if (!canChooseToken) return LudoMoveResult.rollRequired;
    if (tokenIndex < 0 || tokenIndex >= LudoModel.tokensPerPlayer) {
      return LudoMoveResult.invalidToken;
    }
    final player = model.currentPlayer;
    return _moveToken(player, tokenIndex);
  }

  LudoMoveResult _moveToken(int player, int tokenIndex) {
    final start = model.progressFor(player, tokenIndex);
    final result = model.moveToken(player, tokenIndex);
    if (result != LudoMoveResult.accepted) return result;

    final end = model.lastMove!.endProgress;
    _animationPlayer = player;
    _animationToken = tokenIndex;
    _pendingProgress
      ..clear()
      ..addAll(
        start == LudoModel.boxProgress
            ? [end]
            : [
                for (var progress = start + 1; progress <= end; progress++)
                  progress,
              ],
      );
    notifyListeners();

    if (_pendingProgress.isEmpty || movementStepDuration == Duration.zero) {
      _finishMovement();
    } else {
      _scheduleNextStep();
    }
    return result;
  }

  void _scheduleNextStep() {
    if (_disposed ||
        !_acceptsTurns ||
        _movementTimer != null ||
        _pendingProgress.isEmpty) {
      return;
    }
    _movementTimer = Timer(movementStepDuration, () {
      _movementTimer = null;
      if (_disposed || !_acceptsTurns) return;
      _displayProgress[_animationPlayer!][_animationToken!] = _pendingProgress
          .removeAt(0);
      notifyListeners();
      if (_pendingProgress.isEmpty) {
        _finishMovement();
      } else {
        _scheduleNextStep();
      }
    });
  }

  void _finishMovement() {
    _movementTimer?.cancel();
    _movementTimer = null;
    _pendingProgress.clear();
    for (var player = 0; player < model.playerCount; player++) {
      for (var token = 0; token < LudoModel.tokensPerPlayer; token++) {
        _displayProgress[player][token] = model.progressFor(player, token);
      }
    }
    _animationPlayer = null;
    _animationToken = null;
    _saveProgress();
    notifyListeners();
    if (model.isFinished) {
      _publishResult();
      return;
    }
    _scheduleBotAction();
  }

  void _scheduleBotAction() {
    if (_disposed ||
        !_acceptsTurns ||
        model.isFinished ||
        isAnimating ||
        !isBotTurn ||
        _botTimer != null) {
      return;
    }
    final action = model.phase == LudoTurnPhase.awaitingRoll
        ? LudoBotAction.rolling
        : LudoBotAction.choosingToken;
    _pendingBotAction = action;
    final delay = switch (action) {
      LudoBotAction.rolling => botRollDelay ?? _naturalRollDelay(),
      LudoBotAction.choosingToken => botMoveDelay ?? _naturalMoveDelay(),
    };
    _botTimer = Timer(delay, () {
      _botTimer = null;
      _pendingBotAction = null;
      if (_disposed ||
          !_acceptsTurns ||
          model.isFinished ||
          !isBotTurn ||
          isAnimating) {
        return;
      }
      switch (action) {
        case LudoBotAction.rolling:
          if (model.phase == LudoTurnPhase.awaitingRoll) _performRoll();
        case LudoBotAction.choosingToken:
          if (model.phase != LudoTurnPhase.awaitingMove) return;
          final legalTokens = model.legalTokenIndexes;
          if (legalTokens.isEmpty) return;
          final difficulty = _participants[model.currentPlayer]!.botDifficulty!;
          final token = _bot.chooseToken(model, difficulty);
          _moveToken(model.currentPlayer, token);
      }
    });
    notifyListeners();
  }

  void _syncSession() {
    if (_disposed || session == null) return;
    final roundChanged = session!.round != _observedRound;
    if (roundChanged) {
      _observedRound = session!.round;
      if (_hasStartedRound) {
        _cancelTimers(clearMovement: true);
        model.reset();
        _syncDisplayToModel();
        final storage = repository;
        if (storage != null) unawaited(storage.clear(session!.options));
      } else {
        _hasStartedRound = true;
      }
    }

    final phaseChanged = session!.phase != _observedPhase;
    _observedPhase = session!.phase;
    if (!_acceptsTurns) {
      _movementTimer?.cancel();
      _movementTimer = null;
      _cancelBotAction();
      _saveProgress();
    } else if (roundChanged || phaseChanged) {
      if (_pendingProgress.isNotEmpty) {
        _scheduleNextStep();
      } else {
        _scheduleBotAction();
      }
    }
    if (roundChanged || phaseChanged) notifyListeners();
  }

  void _publishResult() {
    final activeSession = session;
    if (activeSession == null ||
        activeSession.phase != MatchPhase.playing ||
        !model.isFinished) {
      return;
    }
    final standings = model.standings;
    final details = standings.indexed
        .map(
          (entry) =>
              '${entry.$1 + 1}. ${activeSession.options.playerLabel(entry.$2)}',
        )
        .join('  •  ');
    activeSession.reportNonPointResult(
      winner: model.winner,
      scores: [
        for (final tokens in model.tokenProgress)
          tokens
              .where((progress) => progress == LudoModel.finishProgress)
              .length,
      ],
      standings: standings,
      details: '$details  •  Another match?',
    );
  }

  void _saveProgress() {
    final storage = repository;
    final options = session?.options;
    if (storage == null || options == null) return;
    unawaited(storage.save(options, model));
  }

  void _syncDisplayToModel() {
    for (var player = 0; player < model.playerCount; player++) {
      for (var token = 0; token < LudoModel.tokensPerPlayer; token++) {
        _displayProgress[player][token] = model.progressFor(player, token);
      }
    }
  }

  void _cancelBotAction() {
    _botTimer?.cancel();
    _botTimer = null;
    _pendingBotAction = null;
  }

  void _cancelTimers({required bool clearMovement}) {
    _movementTimer?.cancel();
    _movementTimer = null;
    if (clearMovement) {
      _pendingProgress.clear();
      _animationPlayer = null;
      _animationToken = null;
    }
    _cancelBotAction();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    session?.removeListener(_syncSession);
    _cancelTimers(clearMovement: true);
    super.dispose();
  }

  Duration _naturalRollDelay() =>
      Duration(milliseconds: 650 + _random.nextInt(351));

  Duration _naturalMoveDelay() =>
      Duration(milliseconds: 500 + _random.nextInt(351));

  static int _randomRoll() => Random().nextInt(6) + 1;
}
