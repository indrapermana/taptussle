import 'dart:math';

import '../../core/match_options.dart';
import 'checkers_model.dart';

/// Bounded legal-move search for the Checkers bot participant.
class CheckersBot {
  CheckersBot({
    required this.difficulty,
    this.player = 1,
    Random? random,
    int? searchDepth,
    int? nodeBudget,
    double? mistakeChance,
  }) : assert(player == 0 || player == 1),
       _random = random ?? Random(),
       searchDepth = searchDepth ?? _profileFor(difficulty).depth,
       nodeBudget = nodeBudget ?? _profileFor(difficulty).nodes,
       mistakeChance = mistakeChance ?? _profileFor(difficulty).mistake {
    if (this.searchDepth < 0) {
      throw ArgumentError.value(this.searchDepth, 'searchDepth');
    }
    if (this.nodeBudget < 1) {
      throw ArgumentError.value(this.nodeBudget, 'nodeBudget');
    }
    if (this.mistakeChance < 0 || this.mistakeChance > 1) {
      throw ArgumentError.value(this.mistakeChance, 'mistakeChance');
    }
  }

  final BotDifficulty difficulty;
  final int player;
  final int searchDepth;
  final int nodeBudget;
  final double mistakeChance;
  final Random _random;

  int _searchedNodes = 0;
  int get searchedNodes => _searchedNodes;

  CheckersMove? chooseMove(CheckersModel model) {
    _searchedNodes = 0;
    if (model.isFinished || model.currentPlayer != player) return null;
    final legal = model.legalMoves;
    if (legal.isEmpty) return null;
    if (difficulty == BotDifficulty.easy ||
        _random.nextDouble() < mistakeChance) {
      return legal[_random.nextInt(legal.length)];
    }

    var bestScore = -_infinity;
    final bestMoves = <CheckersMove>[];
    for (final move in _orderedMoves(legal)) {
      if (_searchedNodes >= nodeBudget) break;
      final child = CheckersModel.copy(model);
      child.play(player, move);
      final completedTurn = child.currentPlayer != model.currentPlayer;
      final score = _search(
        child,
        remainingDepth: searchDepth - (completedTurn ? 1 : 0),
        alpha: -_infinity,
        beta: _infinity,
      );
      if (score > bestScore) {
        bestScore = score;
        bestMoves
          ..clear()
          ..add(move);
      } else if (score == bestScore) {
        bestMoves.add(move);
      }
    }
    if (bestMoves.isEmpty) return legal.first;
    return bestMoves[_random.nextInt(bestMoves.length)];
  }

  int _search(
    CheckersModel model, {
    required int remainingDepth,
    required int alpha,
    required int beta,
  }) {
    _searchedNodes++;
    if (model.isFinished ||
        remainingDepth <= 0 ||
        _searchedNodes >= nodeBudget) {
      return _evaluate(model);
    }

    final maximizing = model.currentPlayer == player;
    var best = maximizing ? -_infinity : _infinity;
    var lower = alpha;
    var upper = beta;
    for (final move in _orderedMoves(model.legalMoves)) {
      if (_searchedNodes >= nodeBudget) break;
      final child = CheckersModel.copy(model);
      final movingPlayer = model.currentPlayer;
      child.play(movingPlayer, move);
      final completedTurn = child.currentPlayer != movingPlayer;
      final score = _search(
        child,
        remainingDepth: remainingDepth - (completedTurn ? 1 : 0),
        alpha: lower,
        beta: upper,
      );
      if (maximizing) {
        best = max(best, score);
        lower = max(lower, best);
      } else {
        best = min(best, score);
        upper = min(upper, best);
      }
      if (upper <= lower) break;
    }
    return best == -_infinity || best == _infinity ? _evaluate(model) : best;
  }

  int _evaluate(CheckersModel model) {
    if (model.winner == player) return _winningScore;
    if (model.winner == 1 - player) return -_winningScore;
    if (model.isDraw) return 0;

    var score = 0;
    for (var square = 0; square < CheckersModel.squareCount; square++) {
      final piece = model.board[square];
      if (piece == null) continue;
      final direction = piece.player == player ? 1 : -1;
      final row = CheckersModel.rowOf(square);
      final column = CheckersModel.columnOf(square);
      final progress = piece.player == 0 ? 7 - row : row;
      final center = row >= 2 && row <= 5 && column >= 2 && column <= 5 ? 6 : 0;
      final backGuard =
          !piece.isKing &&
              ((piece.player == 0 && row == 7) ||
                  (piece.player == 1 && row == 0))
          ? 5
          : 0;
      score +=
          direction *
          ((piece.isKing ? 175 : 100) + progress * 3 + center + backGuard);
    }
    return score;
  }

  List<CheckersMove> _orderedMoves(List<CheckersMove> moves) {
    final ordered = List<CheckersMove>.of(moves);
    ordered.sort((a, b) {
      final capture = (b.isCapture ? 1 : 0) - (a.isCapture ? 1 : 0);
      if (capture != 0) return capture;
      final aColumn = CheckersModel.columnOf(a.to);
      final bColumn = CheckersModel.columnOf(b.to);
      final center = (aColumn - 3.5).abs().compareTo((bColumn - 3.5).abs());
      if (center != 0) return center;
      return a.to.compareTo(b.to);
    });
    return ordered;
  }

  static ({int depth, int nodes, double mistake}) _profileFor(
    BotDifficulty difficulty,
  ) => switch (difficulty) {
    BotDifficulty.easy => (depth: 0, nodes: 1, mistake: 1),
    BotDifficulty.normal => (depth: 2, nodes: 1400, mistake: .18),
    BotDifficulty.hard => (depth: 4, nodes: 8000, mistake: 0),
  };

  static const int _winningScore = 100000;
  static const int _infinity = 1000000;
}
