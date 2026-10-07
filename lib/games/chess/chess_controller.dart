import 'package:flutter/foundation.dart';

import 'chess_model.dart';

enum ChessTapResult { selected, deselected, moved, promotionRequired, ignored }

/// Owns touch selection and promotion choice independently from match lifecycle.
class ChessController extends ChangeNotifier {
  ChessController({ChessModel? model}) : model = model ?? ChessModel();

  ChessModel model;
  int? selectedSquare;
  List<ChessMove> pendingPromotionMoves = const [];

  bool get isChoosingPromotion => pendingPromotionMoves.isNotEmpty;

  List<ChessMove> get selectedMoves =>
      selectedSquare == null ? const [] : model.legalMovesFrom(selectedSquare!);

  ChessTapResult tapSquare(int square) {
    if (model.isFinished ||
        isChoosingPromotion ||
        !ChessModel.isSquare(square)) {
      return ChessTapResult.ignored;
    }

    final selected = selectedSquare;
    if (selected != null) {
      final matching = selectedMoves
          .where((move) => move.to == square)
          .toList();
      if (matching.length > 1) {
        pendingPromotionMoves = List.unmodifiable(matching);
        notifyListeners();
        return ChessTapResult.promotionRequired;
      }
      if (matching.length == 1) {
        return _play(matching.single);
      }
      if (square == selected) {
        selectedSquare = null;
        notifyListeners();
        return ChessTapResult.deselected;
      }
    }

    final piece = model.pieceAt(square);
    if (piece?.color == model.sideToMove &&
        model.legalMovesFrom(square).isNotEmpty) {
      selectedSquare = square;
      notifyListeners();
      return ChessTapResult.selected;
    }
    return ChessTapResult.ignored;
  }

  ChessTapResult choosePromotion(ChessPieceType type) {
    if (!isChoosingPromotion) return ChessTapResult.ignored;
    ChessMove? selected;
    for (final move in pendingPromotionMoves) {
      if (move.promotion == type) {
        selected = move;
        break;
      }
    }
    if (selected == null) return ChessTapResult.ignored;
    return _play(selected);
  }

  void cancelPromotion() {
    if (!isChoosingPromotion) return;
    pendingPromotionMoves = const [];
    notifyListeners();
  }

  ChessTapResult _play(ChessMove move) {
    final result = model.play(move);
    if (!result.accepted) return ChessTapResult.ignored;
    model = result.model;
    selectedSquare = null;
    pendingPromotionMoves = const [];
    notifyListeners();
    return ChessTapResult.moved;
  }
}
