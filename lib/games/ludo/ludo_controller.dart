import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/match_options.dart';
import 'ludo_bot.dart';
import 'ludo_model.dart';

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
      participants: participants,
      botRollDelay: botRollDelay,
      botMoveDelay: botMoveDelay,
      random: resolvedRandom,
      bot: bot ?? LudoBot(random: resolvedRandom),
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
    _scheduleBotAction();
  }

  final LudoModel model;
  final Duration movementStepDuration;
  final Duration? botRollDelay;
  final Duration? botMoveDelay;
  final List<List<int>> _displayProgress;
  final List<MatchParticipant?> _participants;
  final Random _random;
  final LudoBot _bot;

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
      !isAnimating &&
      !isBotTurn &&
      !isBotThinking &&
      model.phase == LudoTurnPhase.awaitingRoll;
  bool get canChooseToken =>
      !_disposed &&
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
  bool _disposed = false;

  LudoRoll? roll() {
    if (!canRoll) return null;
    return _performRoll();
  }

  LudoRoll _performRoll() {
    final result = model.rollDice();
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
    if (_disposed || _movementTimer != null || _pendingProgress.isEmpty) return;
    _movementTimer = Timer(movementStepDuration, () {
      _movementTimer = null;
      if (_disposed) return;
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
    notifyListeners();
    _scheduleBotAction();
  }

  void _scheduleBotAction() {
    if (_disposed ||
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
      if (_disposed || model.isFinished || !isBotTurn || isAnimating) return;
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

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _movementTimer?.cancel();
    _movementTimer = null;
    _botTimer?.cancel();
    _botTimer = null;
    _pendingBotAction = null;
    super.dispose();
  }

  Duration _naturalRollDelay() =>
      Duration(milliseconds: 650 + _random.nextInt(351));

  Duration _naturalMoveDelay() =>
      Duration(milliseconds: 500 + _random.nextInt(351));

  static int _randomRoll() => Random().nextInt(6) + 1;
}
