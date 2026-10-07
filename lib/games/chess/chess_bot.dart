import 'dart:math';

import '../../core/match_options.dart';
import 'chess_model.dart';

/// Legal-move-only Chess bot with strict depth and node limits.
class ChessBot {
  ChessBot({
    required this.difficulty,
    this.color = ChessColor.black,
    Random? random,
    int? searchDepth,
    int? nodeBudget,
    Duration? timeBudget,
    double? mistakeChance,
  }) : _random = random ?? Random(),
       searchDepth = searchDepth ?? _profile(difficulty).depth,
       nodeBudget = nodeBudget ?? _profile(difficulty).nodes,
       timeBudget = timeBudget ?? _profile(difficulty).time,
       mistakeChance = mistakeChance ?? _profile(difficulty).mistake {
    if (this.searchDepth < 0) {
      throw ArgumentError.value(this.searchDepth, 'searchDepth');
    }
    if (this.nodeBudget < 1) {
      throw ArgumentError.value(this.nodeBudget, 'nodeBudget');
    }
    if (this.timeBudget <= Duration.zero) {
      throw ArgumentError.value(this.timeBudget, 'timeBudget');
    }
    if (this.mistakeChance < 0 || this.mistakeChance > 1) {
      throw ArgumentError.value(this.mistakeChance, 'mistakeChance');
    }
  }

  final BotDifficulty difficulty;
  final ChessColor color;
  final int searchDepth;
  final int nodeBudget;
  final Duration timeBudget;
  final double mistakeChance;
  final Random _random;

  int _searchedNodes = 0;
  final Stopwatch _stopwatch = Stopwatch();
  int get searchedNodes => _searchedNodes;

  ChessMove? chooseMove(ChessModel model) {
    _searchedNodes = 0;
    _stopwatch
      ..reset()
      ..start();
    if (model.isFinished || model.sideToMove != color) {
      _stopwatch.stop();
      return null;
    }
    final legal = model.legalMoves;
    if (legal.isEmpty) {
      _stopwatch.stop();
      return null;
    }
    if (difficulty == BotDifficulty.easy ||
        _random.nextDouble() < mistakeChance) {
      final move = legal[_random.nextInt(legal.length)];
      _stopwatch.stop();
      return move;
    }

    // Always recognize a legal one-move win before spending the bounded search
    // budget. This also prevents device load from hiding an immediate mate.
    for (final move in legal) {
      if (model.play(move).model.winner == color) {
        _stopwatch.stop();
        return move;
      }
    }

    var bestScore = -_infinity;
    final best = <ChessMove>[];
    for (final move in _ordered(model, legal)) {
      if (_atLimit && best.isNotEmpty) break;
      final child = model.play(move).model;
      final score = _search(
        child,
        depth: searchDepth - 1,
        alpha: -_infinity,
        beta: _infinity,
      );
      if (score > bestScore) {
        bestScore = score;
        best
          ..clear()
          ..add(move);
      } else if (score == bestScore) {
        best.add(move);
      }
    }
    _stopwatch.stop();
    if (best.isEmpty) return legal.first;
    return best[_random.nextInt(best.length)];
  }

  int _search(
    ChessModel model, {
    required int depth,
    required int alpha,
    required int beta,
  }) {
    _searchedNodes++;
    if (model.isFinished || depth <= 0 || _atLimit) {
      return _evaluate(model);
    }

    final maximizing = model.sideToMove == color;
    var best = maximizing ? -_infinity : _infinity;
    var lower = alpha;
    var upper = beta;
    for (final move in _ordered(model, model.legalMoves)) {
      if (_atLimit) break;
      final score = _search(
        model.play(move).model,
        depth: depth - 1,
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

  int _evaluate(ChessModel model) {
    if (model.winner == color) return _mateScore;
    if (model.winner == color.opposite) return -_mateScore;
    if (model.isDraw) return 0;

    var score = 0;
    for (var square = 0; square < ChessModel.squareCount; square++) {
      final piece = model.pieceAt(square);
      if (piece == null) continue;
      final direction = piece.color == color ? 1 : -1;
      final file = ChessModel.fileOf(square);
      final rank = ChessModel.rankOf(square);
      final center = (file == 3 || file == 4) && (rank == 3 || rank == 4)
          ? 18
          : (file >= 2 && file <= 5 && rank >= 2 && rank <= 5 ? 7 : 0);
      final pawnProgress = piece.type == ChessPieceType.pawn
          ? (piece.color == ChessColor.white ? rank : 7 - rank) * 3
          : 0;
      score += direction * (_pieceValue(piece.type) + center + pawnProgress);
    }
    if (model.isCheck) {
      score += model.sideToMove == color ? -35 : 35;
    }
    return score;
  }

  List<ChessMove> _ordered(ChessModel model, List<ChessMove> moves) {
    final ordered = List<ChessMove>.of(moves);
    ordered.sort((a, b) {
      final aScore = _moveOrderScore(model, a);
      final bScore = _moveOrderScore(model, b);
      if (aScore != bScore) return bScore.compareTo(aScore);
      return a.to.compareTo(b.to);
    });
    return ordered;
  }

  int _moveOrderScore(ChessModel model, ChessMove move) {
    final moving = model.pieceAt(move.from)!;
    final captured = model.pieceAt(move.to);
    var score = move.promotion == null ? 0 : _pieceValue(move.promotion!);
    if (captured != null) {
      score += _pieceValue(captured.type) * 10 - _pieceValue(moving.type);
    } else if (moving.type == ChessPieceType.pawn &&
        move.to == model.enPassantTarget &&
        ChessModel.fileOf(move.from) != ChessModel.fileOf(move.to)) {
      score += _pieceValue(ChessPieceType.pawn) * 9;
    }
    final file = ChessModel.fileOf(move.to);
    final rank = ChessModel.rankOf(move.to);
    if (file >= 2 && file <= 5 && rank >= 2 && rank <= 5) score += 12;
    return score;
  }

  static int _pieceValue(ChessPieceType type) => switch (type) {
    ChessPieceType.pawn => 100,
    ChessPieceType.knight => 320,
    ChessPieceType.bishop => 330,
    ChessPieceType.rook => 500,
    ChessPieceType.queen => 900,
    ChessPieceType.king => 20000,
  };

  bool get _atLimit =>
      _searchedNodes >= nodeBudget || _stopwatch.elapsed >= timeBudget;

  static ({int depth, int nodes, Duration time, double mistake}) _profile(
    BotDifficulty difficulty,
  ) => switch (difficulty) {
    BotDifficulty.easy => (
      depth: 0,
      nodes: 1,
      time: const Duration(milliseconds: 20),
      mistake: 1,
    ),
    BotDifficulty.normal => (
      depth: 2,
      nodes: 700,
      time: const Duration(milliseconds: 400),
      mistake: .16,
    ),
    BotDifficulty.hard => (
      depth: 3,
      nodes: 3500,
      time: const Duration(milliseconds: 900),
      mistake: 0,
    ),
  };

  static const _mateScore = 1000000;
  static const _infinity = 2000000;
}
