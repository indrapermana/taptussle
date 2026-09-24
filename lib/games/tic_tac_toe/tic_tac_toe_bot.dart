import 'dart:math';

import '../../core/match_options.dart';
import 'tic_tac_toe_model.dart';

/// Chooses one legal move without mutating the supplied model.
class TicTacToeBot {
  TicTacToeBot({
    required this.difficulty,
    this.player = 1,
    Random? random,
    this.normalMistakeChance = .2,
  }) : assert(player == 0 || player == 1),
       assert(normalMistakeChance >= 0 && normalMistakeChance <= 1),
       _random = random ?? Random();

  final BotDifficulty difficulty;
  final int player;
  final double normalMistakeChance;
  final Random _random;

  int? chooseMove(TicTacToeModel model) {
    if (model.isFinished || model.currentPlayer != player) return null;
    final legal = model.availableCells;
    if (legal.isEmpty) return null;
    return switch (difficulty) {
      BotDifficulty.easy => _randomMove(legal),
      BotDifficulty.normal => _normalMove(model, legal),
      BotDifficulty.hard => _hardMove(model, legal),
    };
  }

  int _normalMove(TicTacToeModel model, List<int> legal) {
    if (_random.nextDouble() < normalMistakeChance) {
      return _randomMove(legal);
    }
    final board = model.board.toList();
    final ownMark = model.markForPlayer(player);
    final opponentMark = model.markForPlayer(1 - player);
    return _immediateWinningCell(board, ownMark) ??
        _immediateWinningCell(board, opponentMark) ??
        _preferredMove(legal);
  }

  int _hardMove(TicTacToeModel model, List<int> legal) {
    final board = model.board.toList();
    var bestScore = -100;
    var bestMove = legal.first;
    for (final cell in _preferredOrder.where(legal.contains)) {
      board[cell] = model.markForPlayer(player);
      final score = _minimax(board, currentPlayer: 1 - player, depth: 1);
      board[cell] = null;
      if (score > bestScore) {
        bestScore = score;
        bestMove = cell;
      }
    }
    return bestMove;
  }

  int _minimax(
    List<TicTacToeMark?> board, {
    required int currentPlayer,
    required int depth,
  }) {
    final winner = _winner(board);
    if (winner == player) return 10 - depth;
    if (winner == 1 - player) return depth - 10;
    if (board.every((mark) => mark != null)) return 0;

    final maximizing = currentPlayer == player;
    var bestScore = maximizing ? -100 : 100;
    final mark = currentPlayer == 0 ? TicTacToeMark.x : TicTacToeMark.o;
    for (final cell in _preferredOrder) {
      if (board[cell] != null) continue;
      board[cell] = mark;
      final score = _minimax(
        board,
        currentPlayer: 1 - currentPlayer,
        depth: depth + 1,
      );
      board[cell] = null;
      bestScore = maximizing ? max(bestScore, score) : min(bestScore, score);
    }
    return bestScore;
  }

  int? _immediateWinningCell(List<TicTacToeMark?> board, TicTacToeMark mark) {
    for (final cell in _preferredOrder) {
      if (board[cell] != null) continue;
      board[cell] = mark;
      final wins = _winningMark(board) == mark;
      board[cell] = null;
      if (wins) return cell;
    }
    return null;
  }

  int? _winner(List<TicTacToeMark?> board) {
    final mark = _winningMark(board);
    if (mark == TicTacToeMark.x) return 0;
    if (mark == TicTacToeMark.o) return 1;
    return null;
  }

  TicTacToeMark? _winningMark(List<TicTacToeMark?> board) {
    for (final line in TicTacToeModel.winningLines) {
      final mark = board[line.first];
      if (mark != null && line.every((cell) => board[cell] == mark)) {
        return mark;
      }
    }
    return null;
  }

  int _randomMove(List<int> legal) => legal[_random.nextInt(legal.length)];

  int _preferredMove(List<int> legal) =>
      _preferredOrder.firstWhere(legal.contains);

  static const _preferredOrder = [4, 0, 2, 6, 8, 1, 3, 5, 7];
}
