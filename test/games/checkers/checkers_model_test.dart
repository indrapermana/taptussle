import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/checkers/checkers_model.dart';

void main() {
  group('CheckersModel', () {
    test('creates the standard board and opening legal moves', () {
      final model = CheckersModel();

      expect(model.board, hasLength(64));
      expect(model.pieceCount(0), 12);
      expect(model.pieceCount(1), 12);
      expect(model.currentPlayer, 0);
      expect(model.legalMoves, hasLength(7));
      expect(model.legalMoves, everyElement(isA<CheckersMove>()));
      expect(
        model.legalMoves,
        everyElement(predicate<CheckersMove>((move) => !move.isCapture)),
      );
    });

    test('accepts diagonal moves and rejects malformed or illegal input', () {
      final model = CheckersModel();
      const opening = CheckersMove(from: 40, to: 33);

      expect(model.play(1, opening), CheckersMoveResult.wrongOwner);
      expect(model.play(-1, opening), CheckersMoveResult.invalidPlayer);
      expect(
        model.play(0, const CheckersMove(from: -1, to: 8)),
        CheckersMoveResult.outOfBounds,
      );
      expect(
        model.play(0, const CheckersMove(from: 33, to: 26)),
        CheckersMoveResult.emptySource,
      );
      expect(
        model.play(0, const CheckersMove(from: 40, to: 32)),
        CheckersMoveResult.illegalMove,
      );
      expect(model.play(0, opening), CheckersMoveResult.accepted);
      expect(model.board[40], isNull);
      expect(model.board[33], const CheckersPiece(player: 0));
      expect(model.currentPlayer, 1);
    });

    test('requires a capture anywhere on the board', () {
      final model = CheckersModel.fromBoard(
        board: {
          40: const CheckersPiece(player: 0),
          46: const CheckersPiece(player: 0),
          33: const CheckersPiece(player: 1),
          17: const CheckersPiece(player: 1),
        },
      );

      expect(model.legalMoves, const [
        CheckersMove(from: 40, to: 26, captured: 33),
      ]);
      expect(
        model.play(0, const CheckersMove(from: 46, to: 37)),
        CheckersMoveResult.illegalMove,
      );
    });

    test('locks a multi-jump chain to the capturing piece', () {
      final model = CheckersModel.fromBoard(
        board: {
          56: const CheckersPiece(player: 0),
          58: const CheckersPiece(player: 0),
          49: const CheckersPiece(player: 1),
          35: const CheckersPiece(player: 1),
          21: const CheckersPiece(player: 1),
          1: const CheckersPiece(player: 1),
        },
      );

      expect(
        model.play(0, const CheckersMove(from: 56, to: 42)),
        CheckersMoveResult.accepted,
      );
      expect(model.currentPlayer, 0);
      expect(model.forcedCaptureSquare, 42);
      expect(model.legalMoves, const [
        CheckersMove(from: 42, to: 28, captured: 35),
      ]);
      expect(
        model.play(0, const CheckersMove(from: 58, to: 51)),
        CheckersMoveResult.illegalMove,
      );
      expect(
        model.play(0, const CheckersMove(from: 42, to: 28)),
        CheckersMoveResult.accepted,
      );
      expect(model.forcedCaptureSquare, 28);
      expect(
        model.play(0, const CheckersMove(from: 28, to: 14)),
        CheckersMoveResult.accepted,
      );
      expect(model.forcedCaptureSquare, isNull);
      expect(model.currentPlayer, 1);
      expect(model.pieceCount(1), 1);
    });

    test('crowns on the back rank and crowning ends a capture turn', () {
      final model = CheckersModel.fromBoard(
        board: {
          17: const CheckersPiece(player: 0),
          10: const CheckersPiece(player: 1),
          12: const CheckersPiece(player: 1),
          62: const CheckersPiece(player: 1),
        },
      );

      expect(
        model.play(0, const CheckersMove(from: 17, to: 3)),
        CheckersMoveResult.accepted,
      );
      expect(model.board[3]?.isKing, isTrue);
      expect(model.forcedCaptureSquare, isNull);
      expect(model.currentPlayer, 1);
    });

    test('kings move and capture backward without flying', () {
      final model = CheckersModel.fromBoard(
        board: {
          26: const CheckersPiece(player: 0, kind: CheckersPieceKind.king),
          35: const CheckersPiece(player: 1),
          1: const CheckersPiece(player: 1),
        },
      );

      expect(
        model.legalMoves,
        contains(const CheckersMove(from: 26, to: 44, captured: 35)),
      );
      expect(
        model.play(0, const CheckersMove(from: 26, to: 53)),
        CheckersMoveResult.illegalMove,
      );
      expect(
        model.play(0, const CheckersMove(from: 26, to: 44)),
        CheckersMoveResult.accepted,
      );
    });

    test('wins after capturing the final opposing piece', () {
      final model = CheckersModel.fromBoard(
        board: {
          40: const CheckersPiece(player: 0),
          33: const CheckersPiece(player: 1),
        },
      );

      expect(
        model.play(0, const CheckersMove(from: 40, to: 26)),
        CheckersMoveResult.accepted,
      );
      expect(model.outcome, CheckersOutcome.playerOneWin);
      expect(model.winner, 0);
      expect(model.legalMoves, isEmpty);
      expect(
        model.play(1, const CheckersMove(from: 26, to: 19)),
        CheckersMoveResult.matchFinished,
      );
    });

    test('a player with pieces but no legal move loses by stalemate', () {
      final model = CheckersModel.fromBoard(
        board: {
          1: const CheckersPiece(player: 0),
          56: const CheckersPiece(player: 1),
        },
      );

      expect(model.outcome, CheckersOutcome.playerTwoWin);
      expect(model.winner, 1);
    });

    test('draws after the configured number of non-progress plies', () {
      final model = CheckersModel.fromBoard(
        board: {
          40: const CheckersPiece(player: 0, kind: CheckersPieceKind.king),
          23: const CheckersPiece(player: 1, kind: CheckersPieceKind.king),
        },
        maximumNonProgressPlies: 4,
      );

      _play(model, 0, 40, 33);
      _play(model, 1, 23, 30);
      _play(model, 0, 33, 40);
      _play(model, 1, 30, 23);

      expect(model.outcome, CheckersOutcome.draw);
      expect(model.drawReason, CheckersDrawReason.noProgress);
      expect(model.winner, isNull);
    });

    test('draws when the same position occurs three times', () {
      final model = CheckersModel.fromBoard(
        board: {
          40: const CheckersPiece(player: 0, kind: CheckersPieceKind.king),
          23: const CheckersPiece(player: 1, kind: CheckersPieceKind.king),
        },
      );

      for (var cycle = 0; cycle < 2; cycle++) {
        _play(model, 0, 40, 33);
        _play(model, 1, 23, 30);
        _play(model, 0, 33, 40);
        _play(model, 1, 30, 23);
      }

      expect(model.outcome, CheckersOutcome.draw);
      expect(model.drawReason, CheckersDrawReason.threefoldRepetition);
    });

    test('rejects pieces placed on non-playable squares', () {
      expect(
        () =>
            CheckersModel.fromBoard(board: {0: const CheckersPiece(player: 0)}),
        throwsArgumentError,
      );
    });

    test('copies complete state for independent move exploration', () {
      final original = CheckersModel.fromBoard(
        board: {
          56: const CheckersPiece(player: 0),
          49: const CheckersPiece(player: 1),
          35: const CheckersPiece(player: 1),
          1: const CheckersPiece(player: 1),
        },
      );
      _play(original, 0, 56, 42);
      final copy = CheckersModel.copy(original);

      expect(copy.board, original.board);
      expect(copy.currentPlayer, original.currentPlayer);
      expect(copy.forcedCaptureSquare, original.forcedCaptureSquare);
      expect(copy.nonProgressPlies, original.nonProgressPlies);

      _play(copy, 0, 42, 28);
      expect(copy.board[42], isNull);
      expect(original.board[42], isNotNull);
      expect(original.forcedCaptureSquare, 42);
    });
  });
}

void _play(CheckersModel model, int player, int from, int to) {
  expect(
    model.play(player, CheckersMove(from: from, to: to)),
    CheckersMoveResult.accepted,
  );
}
