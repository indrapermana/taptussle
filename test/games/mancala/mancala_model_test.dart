import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/mancala/mancala_model.dart';

void main() {
  group('MancalaModel', () {
    test('creates the confirmed 48-stone Kalah board', () {
      final model = MancalaModel();

      expect(model.board, hasLength(14));
      expect(model.board.fold(0, (total, stones) => total + stones), 48);
      expect(model.currentPlayer, 0);
      expect(model.startingPlayer, 0);
      expect(model.stonesInStore(0), 0);
      expect(model.stonesInStore(1), 0);
      expect([
        for (var pit = 0; pit < 6; pit++) model.stonesInPit(0, pit),
      ], everyElement(4));
      expect([
        for (var pit = 0; pit < 6; pit++) model.stonesInPit(1, pit),
      ], everyElement(4));
      expect(model.legalPitsFor(0), [0, 1, 2, 3, 4, 5]);
      expect(model.legalPitsFor(1), isEmpty);
    });

    test('sows counterclockwise into the active player store', () {
      final model = MancalaModel();

      expect(model.play(0, 2), MancalaMoveResult.accepted);

      expect(model.board.take(7), [4, 4, 0, 5, 5, 5, 1]);
      expect(model.lastTurn?.sowingPath, [3, 4, 5, 6]);
      expect(model.lastTurn?.stonesSown, 4);
      expect(model.lastTurn?.extraTurn, isTrue);
      expect(model.currentPlayer, 0);
    });

    test('skips the opposing store while continuing around the board', () {
      final model = MancalaModel.fromBoard(
        board: const [0, 1, 1, 0, 0, 9, 0, 1, 1, 1, 1, 1, 1, 7],
      );

      expect(model.play(0, 5), MancalaMoveResult.accepted);

      expect(model.lastTurn?.sowingPath, [6, 7, 8, 9, 10, 11, 12, 0, 1]);
      expect(model.stonesInStore(1), 7);
      expect(model.stonesInPit(0, 0), 1);
      expect(model.stonesInPit(0, 1), 2);
      expect(model.currentPlayer, 1);
    });

    test(
      'player two sows through their own store and receives an extra turn',
      () {
        final model = MancalaModel.fromBoard(
          board: const [1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0],
          currentPlayer: 1,
        );

        expect(model.play(1, 5), MancalaMoveResult.accepted);

        expect(model.lastTurn?.sowingPath, [13]);
        expect(model.lastTurn?.extraTurn, isTrue);
        expect(model.stonesInStore(1), 1);
        expect(model.currentPlayer, 1);
      },
    );

    test('captures the landing stone and non-empty opposite pit', () {
      final model = MancalaModel.fromBoard(
        board: const [1, 0, 1, 0, 0, 0, 0, 1, 0, 4, 0, 0, 0, 0],
      );

      expect(model.play(0, 2), MancalaMoveResult.accepted);

      expect(model.stonesInPit(0, 3), 0);
      expect(model.stonesInPit(1, 2), 0);
      expect(model.stonesInStore(0), 5);
      expect(model.lastTurn?.capturedStones, 5);
      expect(model.lastTurn?.wasCapture, isTrue);
      expect(model.currentPlayer, 1);
    });

    test('does not capture when the opposite pit is empty', () {
      final model = MancalaModel.fromBoard(
        board: const [1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0],
      );

      expect(model.play(0, 2), MancalaMoveResult.accepted);

      expect(model.stonesInPit(0, 3), 1);
      expect(model.stonesInStore(0), 0);
      expect(model.lastTurn?.capturedStones, 0);
    });

    test('immediately collects remaining stones and determines the winner', () {
      final model = MancalaModel.fromBoard(
        board: const [0, 0, 0, 0, 0, 1, 20, 3, 0, 0, 0, 0, 0, 20],
      );

      expect(model.play(0, 5), MancalaMoveResult.accepted);

      expect(model.board.take(6), everyElement(0));
      expect(model.board.skip(7).take(6), everyElement(0));
      expect(model.stonesInStore(0), 21);
      expect(model.stonesInStore(1), 23);
      expect(model.outcome, MancalaOutcome.playerTwoWin);
      expect(model.winner, 1);
      expect(model.lastTurn?.finished, isTrue);
      expect(model.lastTurn?.extraTurn, isFalse);
      expect(model.legalPitsFor(0), isEmpty);
    });

    test('supports equal final stores as a draw', () {
      final model = MancalaModel.fromBoard(
        board: const [0, 0, 0, 0, 0, 1, 23, 1, 0, 0, 0, 0, 0, 23],
      );

      expect(model.play(0, 5), MancalaMoveResult.accepted);

      expect(model.stonesInStore(0), 24);
      expect(model.stonesInStore(1), 24);
      expect(model.outcome, MancalaOutcome.draw);
      expect(model.isDraw, isTrue);
      expect(model.winner, isNull);
    });

    test('resolves a supplied side-empty position immediately', () {
      final model = MancalaModel.fromBoard(
        board: const [0, 0, 0, 0, 0, 0, 12, 1, 2, 3, 4, 5, 6, 7],
      );

      expect(model.isFinished, isTrue);
      expect(model.stonesInStore(0), 12);
      expect(model.stonesInStore(1), 28);
      expect(model.outcome, MancalaOutcome.playerTwoWin);
    });

    test('rejects invalid, out-of-turn, empty, and post-match moves', () {
      final model = MancalaModel.fromBoard(
        board: const [1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0],
      );

      expect(model.play(-1, 0), MancalaMoveResult.invalidPlayer);
      expect(model.play(0, 6), MancalaMoveResult.invalidPit);
      expect(model.play(1, 0), MancalaMoveResult.wrongTurn);
      expect(model.play(0, 1), MancalaMoveResult.emptyPit);

      final finished = MancalaModel.fromBoard(
        board: const [0, 0, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 0, 24],
      );
      expect(finished.play(0, 0), MancalaMoveResult.matchFinished);
    });

    test('validates constructed state and returns immutable board data', () {
      expect(() => MancalaModel(startingPlayer: 2), throwsArgumentError);
      expect(
        () => MancalaModel.fromBoard(board: const [1, 2]),
        throwsArgumentError,
      );
      expect(
        () => MancalaModel.fromBoard(
          board: const [4, 4, 4, 4, 4, -1, 0, 4, 4, 4, 4, 4, 4, 0],
        ),
        throwsArgumentError,
      );

      final model = MancalaModel();
      expect(() => model.board[0] = 10, throwsUnsupportedError);
      expect(() => model.boardPositionForPit(0, 6), throwsRangeError);
    });

    test('copies state independently for future bot search', () {
      final original = MancalaModel();
      expect(original.play(0, 0), MancalaMoveResult.accepted);
      final copy = MancalaModel.copy(original);

      expect(copy.board, original.board);
      expect(copy.currentPlayer, original.currentPlayer);
      expect(copy.lastTurn?.sowingPath, original.lastTurn?.sowingPath);

      expect(copy.play(copy.currentPlayer, 0), MancalaMoveResult.accepted);
      expect(copy.board, isNot(original.board));
    });
  });
}
