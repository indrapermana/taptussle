import 'package:flutter/foundation.dart';

import '../../core/match_session.dart';
import 'checkers_model.dart';

enum CheckersTapResult { selected, deselected, moved, ignored }

/// Owns board selection and shared match lifecycle around [CheckersModel].
class CheckersController extends ChangeNotifier {
  CheckersController({required this.session, CheckersModel? model})
    : model = model ?? CheckersModel() {
    session.addListener(_syncSession);
    _syncSession();
  }

  final MatchSession session;
  CheckersModel model;

  int? _selectedSquare;
  int? get selectedSquare => _selectedSquare;

  int _observedRound = 0;
  MatchPhase _observedPhase = MatchPhase.ready;
  bool _hasStartedRound = false;
  bool _disposed = false;

  bool get acceptsInput =>
      !_disposed && session.phase == MatchPhase.playing && !model.isFinished;

  List<CheckersMove> get selectedMoves => _selectedSquare == null
      ? const []
      : model.legalMovesFrom(_selectedSquare!);

  CheckersTapResult tapSquare(int square) {
    if (!acceptsInput || square < 0 || square >= CheckersModel.squareCount) {
      return CheckersTapResult.ignored;
    }

    final selected = _selectedSquare;
    if (selected != null) {
      for (final move in selectedMoves) {
        if (move.to != square) continue;
        final result = model.play(model.currentPlayer, move);
        if (result != CheckersMoveResult.accepted) {
          return CheckersTapResult.ignored;
        }
        _selectedSquare = model.forcedCaptureSquare;
        notifyListeners();
        if (model.isFinished) _publishResult();
        return CheckersTapResult.moved;
      }
      if (square == selected && model.forcedCaptureSquare == null) {
        _selectedSquare = null;
        notifyListeners();
        return CheckersTapResult.deselected;
      }
    }

    final piece = model.board[square];
    if (piece?.player == model.currentPlayer &&
        model.legalMovesFrom(square).isNotEmpty) {
      _selectedSquare = square;
      notifyListeners();
      return CheckersTapResult.selected;
    }
    return CheckersTapResult.ignored;
  }

  void _syncSession() {
    if (_disposed) return;
    final roundChanged = session.round != _observedRound;
    if (roundChanged) {
      _observedRound = session.round;
      if (session.round > 0) {
        if (_hasStartedRound) {
          model = CheckersModel(startingPlayer: 1 - model.startingPlayer);
        } else {
          _hasStartedRound = true;
        }
        _selectedSquare = null;
      }
    }

    final phaseChanged = session.phase != _observedPhase;
    _observedPhase = session.phase;
    if (roundChanged || phaseChanged) notifyListeners();
  }

  void _publishResult() {
    final winner = model.winner;
    if (winner != null) {
      session.reportNonPointResult(
        winner: winner,
        scores: winner == 0 ? const [1, 0] : const [0, 1],
        details:
            '${session.options.playerLabel(winner)} leaves the opponent with no legal move. • Another round?',
      );
      return;
    }

    final reason = switch (model.drawReason) {
      CheckersDrawReason.threefoldRepetition =>
        'The same position occurred three times.',
      CheckersDrawReason.noProgress =>
        'Forty moves per player passed without a capture or promotion.',
      null => 'Neither player can force a result.',
    };
    session.reportNonPointResult(
      winner: null,
      scores: const [0, 0],
      details: '$reason • Another round?',
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
