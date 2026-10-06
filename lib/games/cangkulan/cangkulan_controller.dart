import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/match_session.dart';
import 'cangkulan_model.dart';

enum CangkulanViewPhase { handoff, turn }

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
  }

  final MatchSession session;
  final Random _random;
  final CangkulanModel? _providedInitialModel;
  CangkulanModel model;

  CangkulanViewPhase _phase = CangkulanViewPhase.handoff;
  CangkulanViewPhase get phase => _phase;
  CangkulanTurnAction? _lastAction;
  CangkulanTurnAction? get lastAction => _lastAction;
  int _observedRound = 0;
  MatchPhase _observedSessionPhase = MatchPhase.ready;
  bool _hasStarted = false;
  bool _disposed = false;

  int get activePlayer => model.currentPlayer;
  bool get isHandVisible =>
      !_disposed &&
      session.phase == MatchPhase.playing &&
      _phase == CangkulanViewPhase.turn &&
      !model.isFinished;
  bool get canRevealHand =>
      !_disposed &&
      session.phase == MatchPhase.playing &&
      _phase == CangkulanViewPhase.handoff &&
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
    _phase = CangkulanViewPhase.handoff;
    if (model.isFinished) {
      final winner = model.matchResult!.winner;
      session.reportNonPointResult(
        winner: winner,
        details:
            '${session.options.playerLabel(winner)} emptied their hand first.',
      );
      notifyListeners();
      return CangkulanInteractionResult.matchFinished;
    }
    notifyListeners();
    return CangkulanInteractionResult.accepted;
  }

  void _syncSession() {
    if (_disposed) return;
    final roundChanged = session.round != _observedRound;
    if (roundChanged && session.round > 0) {
      if (_hasStarted) {
        model = _newGame();
      } else {
        model = _providedInitialModel ?? _newGame();
        _hasStarted = true;
      }
      _lastAction = null;
      _phase = CangkulanViewPhase.handoff;
    }

    final phaseChanged = session.phase != _observedSessionPhase;
    if (phaseChanged && session.phase != MatchPhase.playing) {
      _phase = CangkulanViewPhase.handoff;
    }
    _observedRound = session.round;
    _observedSessionPhase = session.phase;
    if (roundChanged || phaseChanged) notifyListeners();
  }

  CangkulanModel _newGame() {
    final deck = CangkulanModel.standardDeck().toList()..shuffle(_random);
    return CangkulanModel.newGame(
      participantCount: session.options.participants.length,
      deck: deck,
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    session.removeListener(_syncSession);
    super.dispose();
  }
}
