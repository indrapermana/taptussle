import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/match_session.dart';
import 'mancala_model.dart';

enum MancalaTapResult { accepted, ignored }

/// Owns input, sowing presentation, and shared match lifecycle for Mancala.
class MancalaController extends ChangeNotifier {
  MancalaController({
    required this.session,
    MancalaModel? model,
    this.sowingStepDuration = const Duration(milliseconds: 110),
    this.settleDuration = const Duration(milliseconds: 160),
  }) : model = model ?? MancalaModel() {
    _displayBoard = this.model.board;
    session.addListener(_syncSession);
    _syncSession();
  }

  final MatchSession session;
  final Duration sowingStepDuration;
  final Duration settleDuration;
  MancalaModel model;

  late List<int> _displayBoard;
  List<int> get displayBoard => List.unmodifiable(_displayBoard);

  Timer? _animationTimer;
  int? _activePosition;
  int? get activePosition => _activePosition;
  bool get isAnimating => _animationTimer != null;

  int _observedRound = 0;
  MatchPhase _observedPhase = MatchPhase.ready;
  bool _hasStartedRound = false;
  bool _disposed = false;

  bool get acceptsInput =>
      !_disposed &&
      session.phase == MatchPhase.playing &&
      !model.isFinished &&
      !isAnimating;

  MancalaTapResult tapPit(int player, int pit) {
    if (!acceptsInput || player != model.currentPlayer) {
      return MancalaTapResult.ignored;
    }

    final before = model.board;
    final source = model.boardPositionForPit(player, pit);
    final result = model.play(player, pit);
    if (result != MancalaMoveResult.accepted) {
      return MancalaTapResult.ignored;
    }

    _displayBoard = List.of(before)..[source] = 0;
    _activePosition = source;
    notifyListeners();
    _animateSowing(model.lastTurn!.sowingPath, 0);
    return MancalaTapResult.accepted;
  }

  void _animateSowing(List<int> path, int step) {
    if (step >= path.length) {
      _scheduleSettlement();
      return;
    }
    _animationTimer = Timer(sowingStepDuration, () {
      _animationTimer = null;
      if (_disposed) return;
      final position = path[step];
      _displayBoard[position]++;
      _activePosition = position;
      notifyListeners();
      if (step + 1 == path.length) {
        _scheduleSettlement();
      } else {
        _animateSowing(path, step + 1);
      }
    });
  }

  void _scheduleSettlement() {
    _animationTimer = Timer(settleDuration, () {
      _animationTimer = null;
      if (_disposed) return;
      _settleAnimation();
    });
  }

  void _settleAnimation({bool publishResult = true}) {
    _animationTimer?.cancel();
    _animationTimer = null;
    _activePosition = null;
    _displayBoard = model.board;
    notifyListeners();
    if (publishResult && model.isFinished) _publishResult();
  }

  void _syncSession() {
    if (_disposed) return;
    final roundChanged = session.round != _observedRound;
    if (roundChanged) {
      _cancelAnimation();
      _observedRound = session.round;
      if (session.round > 0) {
        if (_hasStartedRound) {
          model = MancalaModel(startingPlayer: 1 - model.startingPlayer);
        } else {
          _hasStartedRound = true;
        }
        _displayBoard = model.board;
        _activePosition = null;
      }
    }

    final phaseChanged = session.phase != _observedPhase;
    _observedPhase = session.phase;
    if (session.phase != MatchPhase.playing && isAnimating) {
      _settleAnimation(publishResult: false);
    } else if (session.phase == MatchPhase.playing &&
        phaseChanged &&
        model.isFinished) {
      _publishResult();
    }
    if (roundChanged || phaseChanged) notifyListeners();
  }

  void _publishResult() {
    if (session.phase != MatchPhase.playing || !model.isFinished) return;
    final scores = [model.stonesInStore(0), model.stonesInStore(1)];
    final winner = model.winner;
    session.reportNonPointResult(
      winner: winner,
      scores: scores,
      details: winner == null
          ? 'Both stores hold ${scores[0]} stones. • Another round?'
          : '${session.options.playerLabel(winner)} collects the most stones. • Another round?',
    );
  }

  void _cancelAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    session.removeListener(_syncSession);
    _cancelAnimation();
    super.dispose();
  }
}
