import 'package:flutter_test/flutter_test.dart';
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
  });
}

int _sq(String value) => ChessModel.parseSquare(value);
ChessPiece _white(ChessPieceType type) => ChessPiece(ChessColor.white, type);
ChessPiece _black(ChessPieceType type) => ChessPiece(ChessColor.black, type);
