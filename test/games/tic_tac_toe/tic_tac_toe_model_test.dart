import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/tic_tac_toe/tic_tac_toe_model.dart';

void main() {
  group('TicTacToeModel', () {
    test('starts with nine empty cells and fixed mark ownership', () {
      final model = TicTacToeModel();

      expect(model.board, hasLength(9));
      expect(model.board, everyElement(isNull));
      expect(model.currentPlayer, 0);
      expect(model.markForPlayer(0), TicTacToeMark.x);
      expect(model.markForPlayer(1), TicTacToeMark.o);
      expect(model.outcome, isNull);
    });

    test('accepts only the current player in an empty valid cell', () {
      final model = TicTacToeModel();

      expect(model.play(1, 0), TicTacToeMoveResult.wrongTurn);
      expect(model.play(-1, 0), TicTacToeMoveResult.invalidPlayer);
      expect(model.play(0, -1), TicTacToeMoveResult.outOfBounds);
      expect(model.play(0, 9), TicTacToeMoveResult.outOfBounds);
      expect(model.moveCount, 0);

      expect(model.play(0, 0), TicTacToeMoveResult.accepted);
      expect(model.board[0], TicTacToeMark.x);
      expect(model.currentPlayer, 1);
      expect(model.play(1, 0), TicTacToeMoveResult.occupied);
      expect(model.moveCount, 1);
    });

    for (final line in TicTacToeModel.winningLines) {
      test('detects winning line $line', () {
        final model = TicTacToeModel();
        final otherCells = [
          for (var cell = 0; cell < TicTacToeModel.cellCount; cell++)
            if (!line.contains(cell)) cell,
        ];

        expect(model.play(0, line[0]), TicTacToeMoveResult.accepted);
        expect(model.play(1, otherCells[0]), TicTacToeMoveResult.accepted);
        expect(model.play(0, line[1]), TicTacToeMoveResult.accepted);
        expect(model.play(1, otherCells[1]), TicTacToeMoveResult.accepted);
        expect(model.play(0, line[2]), TicTacToeMoveResult.accepted);

        expect(model.outcome, TicTacToeOutcome.playerOneWin);
        expect(model.winner, 0);
        expect(model.winningLine, line);
        expect(model.isFinished, isTrue);
      });
    }

    test('detects a full-board draw', () {
      final model = TicTacToeModel();
      const cells = [0, 1, 2, 4, 3, 5, 7, 6, 8];

      for (var turn = 0; turn < cells.length; turn++) {
        expect(
          model.play(turn.isEven ? 0 : 1, cells[turn]),
          TicTacToeMoveResult.accepted,
        );
      }

      expect(model.outcome, TicTacToeOutcome.draw);
      expect(model.isDraw, isTrue);
      expect(model.winner, isNull);
      expect(model.winningLine, isNull);
    });

    test('rejects moves after a terminal result without changing state', () {
      final model = TicTacToeModel();
      for (final move in const [(0, 0), (1, 3), (0, 1), (1, 4), (0, 2)]) {
        expect(model.play(move.$1, move.$2), TicTacToeMoveResult.accepted);
      }
      final finishedBoard = model.board;

      expect(model.play(1, 5), TicTacToeMoveResult.matchFinished);
      expect(model.board, finishedBoard);
      expect(model.moveCount, 5);
    });

    test('rematches alternate the starter and clear all match state', () {
      final model = TicTacToeModel();
      expect(model.play(0, 0), TicTacToeMoveResult.accepted);

      model.startRematch();

      expect(model.startingPlayer, 1);
      expect(model.currentPlayer, 1);
      expect(model.board, everyElement(isNull));
      expect(model.moveCount, 0);
      expect(model.outcome, isNull);
      expect(model.play(1, 4), TicTacToeMoveResult.accepted);
      expect(model.board[4], TicTacToeMark.o);

      model.startRematch();
      expect(model.startingPlayer, 0);
      expect(model.currentPlayer, 0);
    });

    test('reset clears the board without changing the starter', () {
      final model = TicTacToeModel(startingPlayer: 1);
      expect(model.play(1, 4), TicTacToeMoveResult.accepted);

      model.reset();

      expect(model.startingPlayer, 1);
      expect(model.currentPlayer, 1);
      expect(model.board, everyElement(isNull));
    });
  });
}
