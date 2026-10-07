import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/chess/chess_controller.dart';
import 'package:tap_tussle/games/chess/chess_model.dart';

void main() {
  group('ChessController', () {
    test('selects, deselects, and plays legal moves', () {
      final controller = ChessController();
      addTearDown(controller.dispose);

      expect(controller.tapSquare(_sq('e2')), ChessTapResult.selected);
      expect(controller.selectedSquare, _sq('e2'));
      expect(controller.tapSquare(_sq('e2')), ChessTapResult.deselected);
      expect(controller.tapSquare(_sq('e2')), ChessTapResult.selected);
      expect(controller.tapSquare(_sq('e4')), ChessTapResult.moved);
      expect(controller.selectedSquare, isNull);
      expect(controller.model.pieceAt(_sq('e4'))?.type, ChessPieceType.pawn);
      expect(controller.model.history.single.notation, 'e4');
    });

    test('ignores opponent, invalid, and unavailable destinations', () {
      final controller = ChessController();
      addTearDown(controller.dispose);

      expect(controller.tapSquare(_sq('e7')), ChessTapResult.ignored);
      expect(controller.tapSquare(-1), ChessTapResult.ignored);
      expect(controller.tapSquare(_sq('e2')), ChessTapResult.selected);
      expect(controller.tapSquare(_sq('e5')), ChessTapResult.ignored);
      expect(controller.selectedSquare, _sq('e2'));
    });

    test('requires an explicit promotion choice and supports cancellation', () {
      final controller = ChessController(
        model: ChessModel.fromState(
          board: {
            _sq('e1'): _white(ChessPieceType.king),
            _sq('a7'): _white(ChessPieceType.pawn),
            _sq('e8'): _black(ChessPieceType.king),
          },
        ),
      );
      addTearDown(controller.dispose);

      expect(controller.tapSquare(_sq('a7')), ChessTapResult.selected);
      expect(controller.tapSquare(_sq('a8')), ChessTapResult.promotionRequired);
      expect(controller.isChoosingPromotion, isTrue);
      expect(controller.pendingPromotionMoves, hasLength(4));
      expect(controller.tapSquare(_sq('e1')), ChessTapResult.ignored);

      controller.cancelPromotion();
      expect(controller.isChoosingPromotion, isFalse);
      expect(controller.selectedSquare, _sq('a7'));
      expect(controller.tapSquare(_sq('a8')), ChessTapResult.promotionRequired);
      expect(
        controller.choosePromotion(ChessPieceType.knight),
        ChessTapResult.moved,
      );
      expect(
        controller.model.pieceAt(_sq('a8')),
        _white(ChessPieceType.knight),
      );
    });

    test('blocks interaction after the game has finished', () {
      final controller = ChessController(
        model: ChessModel.fromState(
          board: {
            _sq('h8'): _black(ChessPieceType.king),
            _sq('g7'): _white(ChessPieceType.queen),
            _sq('g6'): _white(ChessPieceType.king),
          },
          sideToMove: ChessColor.black,
        ),
      );
      addTearDown(controller.dispose);

      expect(controller.model.isCheckmate, isTrue);
      expect(controller.tapSquare(_sq('h8')), ChessTapResult.ignored);
    });

    test(
      'friend session accepts alternating turns and publishes checkmate',
      () {
        final session = MatchSession(options: MatchOptions.friend())..start();
        final controller = ChessController(session: session);
        addTearDown(controller.dispose);
        addTearDown(session.dispose);

        _tapMove(controller, 'f2', 'f3');
        _tapMove(controller, 'e7', 'e5');
        _tapMove(controller, 'g2', 'g4');
        _tapMove(controller, 'd8', 'h4');

        expect(session.phase, MatchPhase.finished);
        expect(session.outcome, MatchOutcome.winner);
        expect(session.winner, 1);
        expect(session.scores, [0, 1]);
        expect(session.resultDetails, contains('Player 2 wins by checkmate'));
      },
    );

    testWidgets('bot waits visibly, blocks input, and makes one legal move', (
      tester,
    ) async {
      final session = MatchSession(
        options: MatchOptions.bot(difficulty: BotDifficulty.easy),
      )..start();
      final controller = ChessController(
        session: session,
        random: Random(4),
        botThinkDelay: const Duration(milliseconds: 20),
      );
      addTearDown(controller.dispose);
      addTearDown(session.dispose);

      _tapMove(controller, 'e2', 'e4');
      expect(controller.isBotThinking, isTrue);
      expect(controller.acceptsInput, isFalse);
      expect(controller.tapSquare(_sq('e7')), ChessTapResult.ignored);

      await tester.pump(const Duration(milliseconds: 19));
      expect(controller.model.sideToMove, ChessColor.black);
      await tester.pump(const Duration(milliseconds: 1));
      expect(controller.model.sideToMove, ChessColor.white);
      expect(controller.model.history, hasLength(2));
    });

    testWidgets('pause cancels bot work and resume starts a fresh delay', (
      tester,
    ) async {
      final session = MatchSession(
        options: MatchOptions.bot(difficulty: BotDifficulty.normal),
      )..start();
      final controller = ChessController(
        session: session,
        random: Random(5),
        botThinkDelay: const Duration(milliseconds: 20),
      );
      addTearDown(controller.dispose);
      addTearDown(session.dispose);
      _tapMove(controller, 'e2', 'e4');

      session.pause();
      expect(controller.isBotThinking, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(controller.model.history, hasLength(1));

      session.resume();
      expect(controller.isBotThinking, isTrue);
      await tester.pump(const Duration(milliseconds: 20));
      expect(controller.model.history, hasLength(2));
    });

    testWidgets('rematch resets the board and disposal cancels bot work', (
      tester,
    ) async {
      final session = MatchSession(
        options: MatchOptions.bot(difficulty: BotDifficulty.easy),
      )..start();
      final controller = ChessController(
        session: session,
        botThinkDelay: const Duration(milliseconds: 20),
      );
      _tapMove(controller, 'e2', 'e4');
      expect(controller.isBotThinking, isTrue);

      session.reportDraw(0, 0);
      session.start();
      expect(controller.model.history, isEmpty);
      expect(controller.model.sideToMove, ChessColor.white);
      controller.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      session.dispose();
    });
  });
}

void _tapMove(ChessController controller, String from, String to) {
  expect(controller.tapSquare(_sq(from)), ChessTapResult.selected);
  expect(controller.tapSquare(_sq(to)), ChessTapResult.moved);
}

int _sq(String value) => ChessModel.parseSquare(value);
ChessPiece _white(ChessPieceType type) => ChessPiece(ChessColor.white, type);
ChessPiece _black(ChessPieceType type) => ChessPiece(ChessColor.black, type);
