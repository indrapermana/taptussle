import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/checkers/checkers_controller.dart';
import 'package:tap_tussle/games/checkers/checkers_model.dart';

void main() {
  test('selects pieces, moves to legal targets, and supports deselection', () {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final controller = CheckersController(session: session);
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    expect(controller.tapSquare(40), CheckersTapResult.selected);
    expect(controller.selectedSquare, 40);
    expect(controller.tapSquare(40), CheckersTapResult.deselected);
    expect(controller.tapSquare(40), CheckersTapResult.selected);
    expect(controller.tapSquare(33), CheckersTapResult.moved);
    expect(controller.model.board[33], const CheckersPiece(player: 0));
    expect(controller.model.currentPlayer, 1);
    expect(controller.selectedSquare, isNull);
  });

  test('capture continuation remains selected and blocks other pieces', () {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final controller = CheckersController(
      session: session,
      model: CheckersModel.fromBoard(
        board: {
          56: const CheckersPiece(player: 0),
          58: const CheckersPiece(player: 0),
          49: const CheckersPiece(player: 1),
          35: const CheckersPiece(player: 1),
          1: const CheckersPiece(player: 1),
        },
      ),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    expect(controller.tapSquare(56), CheckersTapResult.selected);
    expect(controller.tapSquare(42), CheckersTapResult.moved);
    expect(controller.selectedSquare, 42);
    expect(controller.model.currentPlayer, 0);
    expect(controller.tapSquare(58), CheckersTapResult.ignored);
    expect(controller.selectedSquare, 42);
    expect(controller.tapSquare(28), CheckersTapResult.moved);
    expect(controller.selectedSquare, isNull);
    expect(controller.model.currentPlayer, 1);
  });

  test('publishes winner and draw results through the shared session', () {
    final winnerSession = MatchSession(options: MatchOptions.friend())..start();
    final winnerController = CheckersController(
      session: winnerSession,
      model: CheckersModel.fromBoard(
        board: {
          40: const CheckersPiece(player: 0),
          33: const CheckersPiece(player: 1),
        },
      ),
    );
    addTearDown(winnerController.dispose);
    addTearDown(winnerSession.dispose);

    winnerController.tapSquare(40);
    winnerController.tapSquare(26);
    expect(winnerSession.phase, MatchPhase.finished);
    expect(winnerSession.outcome, MatchOutcome.winner);
    expect(winnerSession.winner, 0);
    expect(winnerSession.scores, [1, 0]);

    final drawSession = MatchSession(options: MatchOptions.friend())..start();
    final drawController = CheckersController(
      session: drawSession,
      model: CheckersModel.fromBoard(
        board: {
          40: const CheckersPiece(player: 0, kind: CheckersPieceKind.king),
          23: const CheckersPiece(player: 1, kind: CheckersPieceKind.king),
        },
        maximumNonProgressPlies: 1,
      ),
    );
    addTearDown(drawController.dispose);
    addTearDown(drawSession.dispose);

    drawController.tapSquare(40);
    drawController.tapSquare(33);
    expect(drawSession.phase, MatchPhase.finished);
    expect(drawSession.outcome, MatchOutcome.draw);
    expect(drawSession.resultDetails, contains('Forty moves'));
  });

  test('pause blocks input and rematch alternates the starting player', () {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final controller = CheckersController(
      session: session,
      model: CheckersModel.fromBoard(
        board: {
          40: const CheckersPiece(player: 0),
          33: const CheckersPiece(player: 1),
        },
      ),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    session.pause();
    expect(controller.tapSquare(40), CheckersTapResult.ignored);
    session.resume();
    controller.tapSquare(40);
    controller.tapSquare(26);
    expect(session.phase, MatchPhase.finished);

    session.start();
    expect(controller.model.startingPlayer, 1);
    expect(controller.model.currentPlayer, 1);
    expect(controller.model.pieceCount(0), 12);
    expect(controller.model.pieceCount(1), 12);
  });
}
