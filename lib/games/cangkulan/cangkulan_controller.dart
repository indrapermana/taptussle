import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'cangkulan_bot.dart';
import 'cangkulan_model.dart';
import 'cangkulan_progress_repository.dart';

enum CangkulanViewPhase { handoff, turn, trickResult }

enum CangkulanInteractionResult {
  accepted,
  unavailable,
  illegalAction,
  matchFinished,
}

class CangkulanController extends ChangeNotifier {
  CangkulanController({
    required this.session,
    CangkulanModel? initialModel,
    Random? random,
    this.botThinkDelay,
    this.repository,
  }) : _random = random ?? Random(),
       _providedInitialModel = initialModel,
       model =
           initialModel ??
           CangkulanModel.newGame(
             participantCount: session.options.participants.length,
           ) {
    if (model.participantCount != session.options.participants.length) {
      throw ArgumentError(
        'Model participant count must match the configured match',
      );
    }
    if (initialModel == null) model = _newGame();
    _hasStarted = session.round > 0;
    session.addListener(_syncSession);
    _observedRound = session.round;
    _observedSessionPhase = session.phase;
    _prepareActiveTurn();
    _scheduleBotTurn();
  }

  final MatchSession session;
  final Random _random;
  final CangkulanModel? _providedInitialModel;
  final Duration? botThinkDelay;
  final CangkulanProgressRepository? repository;
  CangkulanModel model;

  CangkulanViewPhase _phase = CangkulanViewPhase.handoff;
  CangkulanViewPhase get phase => _phase;
  CangkulanTurnAction? _lastAction;
  CangkulanTurnAction? get lastAction => _lastAction;
  int _observedRound = 0;
  MatchPhase _observedSessionPhase = MatchPhase.ready;
  bool _hasStarted = false;
  bool _disposed = false;
  Timer? _botTimer;
  Timer? _trickResultTimer;

  int get activePlayer => model.currentPlayer;
  MatchParticipant get activeParticipant =>
      session.options.participants[activePlayer];
  bool get isBotTurn => !model.isFinished && activeParticipant.isBot;
  bool get isBotThinking => _botTimer?.isActive ?? false;
  bool get needsPrivacyHandoff =>
      !isBotTurn &&
      session.options.participants
              .where((participant) => !participant.isBot)
              .length >
          1;
  bool get isHandVisible =>
      !_disposed &&
      session.phase == MatchPhase.playing &&
      _phase == CangkulanViewPhase.turn &&
      !isBotTurn &&
      !model.isFinished;
  bool get canRevealHand =>
      !_disposed &&
      session.phase == MatchPhase.playing &&
      _phase == CangkulanViewPhase.handoff &&
      !isBotTurn &&
      !model.isFinished;
  List<CangkulanCard> get visibleHand =>
      isHandVisible ? model.hands[activePlayer] : const [];
  List<CangkulanLegalAction> get legalActions =>
      isHandVisible ? model.legalActions : const [];

  bool revealHand() {
    if (!canRevealHand) return false;
    _phase = CangkulanViewPhase.turn;
    notifyListeners();
    return true;
  }

  CangkulanInteractionResult playCard(CangkulanCard card) {
    if (!isHandVisible) return CangkulanInteractionResult.unavailable;
    return _apply(CangkulanLegalAction.play(card));
  }

  CangkulanInteractionResult cangkul() {
    if (!isHandVisible) return CangkulanInteractionResult.unavailable;
    return _apply(const CangkulanLegalAction.cangkul());
  }

  CangkulanInteractionResult _apply(CangkulanLegalAction action) {
    if (!model.legalActions.contains(action)) {
      return CangkulanInteractionResult.illegalAction;
    }
    final result = model.performAction(activePlayer, action);
    if (!result.accepted) return CangkulanInteractionResult.illegalAction;
    model = result.model;
    _lastAction = result.action;
    _prepareActiveTurn();
    if (model.isFinished) {
      final storage = repository;
      if (storage != null) unawaited(storage.clear(session.options));
      final result = model.matchResult!;
      final winner = result.winner;
      final standings = List.generate(model.participantCount, (index) => index)
        ..sort((left, right) {
          if (left == winner) return -1;
          if (right == winner) return 1;
          final cards = result.remainingCards[left].compareTo(
            result.remainingCards[right],
          );
          return cards != 0 ? cards : left.compareTo(right);
        });
      final details = standings.indexed
          .map((entry) {
            final cards = result.remainingCards[entry.$2];
            final suffix = cards == 0
                ? 'empty'
                : '$cards card${cards == 1 ? '' : 's'}';
            return '${entry.$1 + 1}. ${session.options.playerLabel(entry.$2)} ($suffix)';
          })
          .join('  •  ');
      session.reportNonPointResult(
        winner: winner,
        scores: [
          for (var player = 0; player < model.participantCount; player++)
            player == winner ? 1 : 0,
        ],
        standings: standings,
        details: details,
      );
      notifyListeners();
      return CangkulanInteractionResult.matchFinished;
    }
    if (result.action?.completedTrick != null) {
      _phase = CangkulanViewPhase.trickResult;
      _saveProgress();
      notifyListeners();
      _trickResultTimer = Timer(
        const Duration(milliseconds: 1200),
        _finishTrickResult,
      );
      return CangkulanInteractionResult.accepted;
    }
    _saveProgress();
    notifyListeners();
    _scheduleBotTurn();
    return CangkulanInteractionResult.accepted;
  }

  void _scheduleBotTurn() {
    if (_disposed ||
        session.phase != MatchPhase.playing ||
        !isBotTurn ||
        _botTimer != null) {
      return;
    }
    _phase = CangkulanViewPhase.handoff;
    _botTimer = Timer(botThinkDelay ?? _naturalThinkDelay(), _performBotTurn);
    notifyListeners();
  }

  void _prepareActiveTurn() {
    _phase = isBotTurn || needsPrivacyHandoff
        ? CangkulanViewPhase.handoff
        : CangkulanViewPhase.turn;
  }

  Duration _naturalThinkDelay() {
    final (minimum, variation) = switch (activeParticipant.botDifficulty!) {
      BotDifficulty.easy => (900, 550),
      BotDifficulty.normal => (700, 450),
      BotDifficulty.hard => (550, 350),
    };
    return Duration(milliseconds: minimum + _random.nextInt(variation));
  }

  void _performBotTurn() {
    _botTimer = null;
    if (_disposed || session.phase != MatchPhase.playing || !isBotTurn) return;
    final player = activePlayer;
    final bot = CangkulanBot(
      difficulty: activeParticipant.botDifficulty!,
      random: _random,
    );
    final action = bot.chooseAction(
      CangkulanBotObservation.fromModel(model, player),
    );
    if (action == null) return;
    _apply(action);
  }

  void _cancelBotTurn() {
    _botTimer?.cancel();
    _botTimer = null;
  }

  void _finishTrickResult() {
    _trickResultTimer = null;
    if (_disposed || session.phase != MatchPhase.playing || model.isFinished) {
      return;
    }
    _prepareActiveTurn();
    notifyListeners();
    _scheduleBotTurn();
  }

  void _cancelTrickResult() {
    _trickResultTimer?.cancel();
    _trickResultTimer = null;
  }

  void _syncSession() {
    if (_disposed) return;
    final roundChanged = session.round != _observedRound;
    if (roundChanged && session.round > 0) {
      _cancelBotTurn();
      _cancelTrickResult();
      if (_hasStarted) {
        final storage = repository;
        if (storage != null) unawaited(storage.clear(session.options));
        model = _newGame();
      } else {
        model = _providedInitialModel ?? _newGame();
        _hasStarted = true;
      }
      _lastAction = null;
      _prepareActiveTurn();
    }

    final phaseChanged = session.phase != _observedSessionPhase;
    if (phaseChanged && session.phase != MatchPhase.playing) {
      _cancelBotTurn();
      _cancelTrickResult();
      _phase = CangkulanViewPhase.handoff;
      _saveProgress();
    }
    _observedRound = session.round;
    _observedSessionPhase = session.phase;
    if (roundChanged || phaseChanged) {
      if (session.phase == MatchPhase.playing) _prepareActiveTurn();
      notifyListeners();
      if (session.phase == MatchPhase.playing) _scheduleBotTurn();
    }
  }

  CangkulanModel _newGame() {
    final deck = CangkulanModel.standardDeck().toList()..shuffle(_random);
    return CangkulanModel.newGame(
      participantCount: session.options.participants.length,
      deck: deck,
    );
  }

  void _saveProgress() {
    final storage = repository;
    if (storage != null) unawaited(storage.save(session.options, model));
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    session.removeListener(_syncSession);
    _cancelBotTurn();
    _cancelTrickResult();
    super.dispose();
  }
}
