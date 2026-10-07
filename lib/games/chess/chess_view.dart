import 'package:flutter/material.dart';

import 'chess_controller.dart';
import 'chess_model.dart';

enum ChessOrientation { white, black }

class ChessView extends StatefulWidget {
  const ChessView({
    this.initialModel,
    this.playerLabels = const ['Player 1', 'Player 2'],
    super.key,
  }) : assert(playerLabels.length == 2);

  final ChessModel? initialModel;
  final List<String> playerLabels;

  @override
  State<ChessView> createState() => _ChessViewState();
}

class _ChessViewState extends State<ChessView> {
  late final ChessController controller;
  var orientation = ChessOrientation.white;

  @override
  void initState() {
    super.initState();
    controller = ChessController(model: widget.initialModel);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => ChessBoard(
      model: controller.model,
      selectedSquare: controller.selectedSquare,
      pendingPromotionMoves: controller.pendingPromotionMoves,
      orientation: orientation,
      playerLabels: widget.playerLabels,
      onSquareTap: controller.tapSquare,
      onPromotionSelected: controller.choosePromotion,
      onPromotionCancelled: controller.cancelPromotion,
      onFlipBoard: () => setState(() {
        orientation = orientation == ChessOrientation.white
            ? ChessOrientation.black
            : ChessOrientation.white;
      }),
    ),
  );
}

/// Responsive, accessible presentation for a standard Chess position.
class ChessBoard extends StatelessWidget {
  const ChessBoard({
    required this.model,
    required this.onSquareTap,
    this.selectedSquare,
    this.pendingPromotionMoves = const [],
    this.orientation = ChessOrientation.white,
    this.playerLabels = const ['Player 1', 'Player 2'],
    this.enabled = true,
    this.statusOverride,
    this.onPromotionSelected,
    this.onPromotionCancelled,
    this.onFlipBoard,
    super.key,
  }) : assert(playerLabels.length == 2);

  final ChessModel model;
  final ValueChanged<int> onSquareTap;
  final int? selectedSquare;
  final List<ChessMove> pendingPromotionMoves;
  final ChessOrientation orientation;
  final List<String> playerLabels;
  final bool enabled;
  final String? statusOverride;
  final ValueChanged<ChessPieceType>? onPromotionSelected;
  final VoidCallback? onPromotionCancelled;
  final VoidCallback? onFlipBoard;

  static const _red = Color(0xFFFF644D);
  static const _blue = Color(0xFF35C8FF);
  static const _lightSquare = Color(0xFFE9D8B4);
  static const _darkSquare = Color(0xFF42627A);
  static const _selected = Color(0xFFFFD54F);
  static const _legal = Color(0xFF70E0A0);
  static const _lastMove = Color(0xFFB7E55C);
  static const _check = Color(0xFFFF5252);

  @override
  Widget build(BuildContext context) {
    final selectedMoves = selectedSquare == null
        ? const <ChessMove>[]
        : model.legalMovesFrom(selectedSquare!);
    final targets = selectedMoves.map((move) => move.to).toSet();
    final lastMove = model.history.isEmpty ? null : model.history.last.move;
    final checkedKing = model.isCheck
        ? model.board.indexWhere(
            (piece) =>
                piece == ChessPiece(model.sideToMove, ChessPieceType.king),
          )
        : null;
    final compactHistory = model.history
        .skip(model.history.length > 8 ? model.history.length - 8 : 0)
        .toList();

    return ColoredBox(
      color: const Color(0xFF0C1724),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 650;
            return Padding(
              padding: EdgeInsets.fromLTRB(12, compact ? 6 : 12, 12, 10),
              child: Column(
                children: [
                  _Header(
                    model: model,
                    playerLabels: playerLabels,
                    orientation: orientation,
                    onFlipBoard: onFlipBoard,
                    compact: compact,
                  ),
                  SizedBox(height: compact ? 5 : 9),
                  Text(
                    statusOverride ?? _statusText(model, playerLabels),
                    key: const ValueKey('chess-status'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: model.isCheck ? _check : Colors.white,
                      fontSize: compact ? 14 : 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                  SizedBox(height: compact ? 5 : 9),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xFF101A27),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white24,
                                width: 4,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Column(
                                children: [
                                  for (
                                    var displayRow = 0;
                                    displayRow < 8;
                                    displayRow++
                                  )
                                    Expanded(
                                      child: Row(
                                        children: [
                                          for (
                                            var displayColumn = 0;
                                            displayColumn < 8;
                                            displayColumn++
                                          )
                                            Expanded(
                                              child: _Square(
                                                square: _displaySquare(
                                                  displayRow,
                                                  displayColumn,
                                                ),
                                                piece: model.pieceAt(
                                                  _displaySquare(
                                                    displayRow,
                                                    displayColumn,
                                                  ),
                                                ),
                                                selected:
                                                    selectedSquare ==
                                                    _displaySquare(
                                                      displayRow,
                                                      displayColumn,
                                                    ),
                                                legalTarget: targets.contains(
                                                  _displaySquare(
                                                    displayRow,
                                                    displayColumn,
                                                  ),
                                                ),
                                                lastMove:
                                                    lastMove?.from ==
                                                        _displaySquare(
                                                          displayRow,
                                                          displayColumn,
                                                        ) ||
                                                    lastMove?.to ==
                                                        _displaySquare(
                                                          displayRow,
                                                          displayColumn,
                                                        ),
                                                inCheck:
                                                    checkedKing ==
                                                    _displaySquare(
                                                      displayRow,
                                                      displayColumn,
                                                    ),
                                                enabled:
                                                    enabled &&
                                                    pendingPromotionMoves
                                                        .isEmpty,
                                                onTap: onSquareTap,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 5 : 8),
                  if (pendingPromotionMoves.isNotEmpty)
                    _PromotionPicker(
                      color: model.sideToMove,
                      options: pendingPromotionMoves
                          .map((move) => move.promotion!)
                          .toSet()
                          .toList(),
                      onSelected: onPromotionSelected,
                      onCancel: onPromotionCancelled,
                      compact: compact,
                    )
                  else
                    _GameDetails(
                      model: model,
                      recentHistory: compactHistory,
                      compact: compact,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  int _displaySquare(int row, int column) {
    final rank = orientation == ChessOrientation.white ? 7 - row : row;
    final file = orientation == ChessOrientation.white ? column : 7 - column;
    return ChessModel.square(file, rank);
  }

  static String _statusText(ChessModel model, List<String> labels) {
    if (model.isCheckmate) {
      final winner = model.winner == ChessColor.white ? labels[0] : labels[1];
      return '${winner.toUpperCase()} WINS • CHECKMATE';
    }
    if (model.isDraw) {
      return switch (model.drawReason) {
        ChessDrawReason.stalemate => 'DRAW • STALEMATE',
        ChessDrawReason.insufficientMaterial => 'DRAW • INSUFFICIENT MATERIAL',
        ChessDrawReason.threefoldRepetition => 'DRAW • THREEFOLD REPETITION',
        ChessDrawReason.fiftyMoveRule => 'DRAW • FIFTY-MOVE RULE',
        null => 'DRAW',
      };
    }
    final player = model.sideToMove == ChessColor.white ? labels[0] : labels[1];
    return '${player.toUpperCase()}'
        '${model.isCheck ? ' • CHECK' : ''}'
        ' • ${model.sideToMove.name.toUpperCase()} TO MOVE';
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.model,
    required this.playerLabels,
    required this.orientation,
    required this.onFlipBoard,
    required this.compact,
  });

  final ChessModel model;
  final List<String> playerLabels;
  final ChessOrientation orientation;
  final VoidCallback? onFlipBoard;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _PlayerBadge(
          label: playerLabels[0],
          colorName: 'White',
          color: ChessBoard._red,
          symbol: '♔',
          active: !model.isFinished && model.sideToMove == ChessColor.white,
          winner: model.winner == ChessColor.white,
          compact: compact,
        ),
      ),
      IconButton(
        key: const ValueKey('chess-flip-board'),
        tooltip: 'Flip board',
        onPressed: onFlipBoard,
        icon: Icon(
          orientation == ChessOrientation.white
              ? Icons.swap_vert_circle_outlined
              : Icons.swap_vert_circle,
          color: Colors.white70,
        ),
      ),
      Expanded(
        child: _PlayerBadge(
          label: playerLabels[1],
          colorName: 'Black',
          color: ChessBoard._blue,
          symbol: '♚',
          active: !model.isFinished && model.sideToMove == ChessColor.black,
          winner: model.winner == ChessColor.black,
          compact: compact,
        ),
      ),
    ],
  );
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({
    required this.label,
    required this.colorName,
    required this.color,
    required this.symbol,
    required this.active,
    required this.winner,
    required this.compact,
  });

  final String label;
  final String colorName;
  final Color color;
  final String symbol;
  final bool active;
  final bool winner;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '$label, $colorName${active ? ', current turn' : ''}${winner ? ', winner' : ''}',
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 5 : 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: active || winner ? .24 : .1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active || winner ? color : Colors.white24,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Text(
            symbol,
            style: TextStyle(fontSize: compact ? 20 : 26, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  colorName.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: compact ? 9 : 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Square extends StatelessWidget {
  const _Square({
    required this.square,
    required this.piece,
    required this.selected,
    required this.legalTarget,
    required this.lastMove,
    required this.inCheck,
    required this.enabled,
    required this.onTap,
  });

  final int square;
  final ChessPiece? piece;
  final bool selected;
  final bool legalTarget;
  final bool lastMove;
  final bool inCheck;
  final bool enabled;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final light =
        (ChessModel.fileOf(square) + ChessModel.rankOf(square)).isEven;
    final base = light ? ChessBoard._darkSquare : ChessBoard._lightSquare;
    final overlay = inCheck
        ? ChessBoard._check
        : selected
        ? ChessBoard._selected
        : lastMove
        ? ChessBoard._lastMove
        : null;
    final label = [
      ChessModel.squareName(square),
      if (piece == null)
        'empty'
      else
        '${piece!.color.name} ${piece!.type.name}',
      if (selected) 'selected',
      if (legalTarget) piece == null ? 'legal target' : 'legal capture',
      if (lastMove) 'last move',
      if (inCheck) 'in check',
    ].join(', ');

    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('chess-square-$square'),
        onTap: enabled ? () => onTap(square) : null,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: overlay == null
              ? base
              : Color.alphaBlend(overlay.withValues(alpha: .68), base),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (piece case final value?)
                FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Text(
                      _pieceSymbol(value),
                      style: TextStyle(
                        fontSize: 48,
                        height: 1,
                        color: value.color == ChessColor.white
                            ? const Color(0xFFFFF7E3)
                            : const Color(0xFF111A27),
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ),
              if (legalTarget)
                IgnorePointer(
                  child: Container(
                    width: piece == null ? 13 : null,
                    height: piece == null ? 13 : null,
                    decoration: BoxDecoration(
                      color: piece == null
                          ? ChessBoard._legal.withValues(alpha: .9)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: piece == null
                          ? null
                          : Border.all(color: ChessBoard._legal, width: 4),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromotionPicker extends StatelessWidget {
  const _PromotionPicker({
    required this.color,
    required this.options,
    required this.onSelected,
    required this.onCancel,
    required this.compact,
  });

  final ChessColor color;
  final List<ChessPieceType> options;
  final ValueChanged<ChessPieceType>? onSelected;
  final VoidCallback? onCancel;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Choose promotion piece',
    explicitChildNodes: true,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 3 : 6),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'PROMOTE TO',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            for (final type in options)
              IconButton(
                key: ValueKey('chess-promote-${type.name}'),
                tooltip: 'Promote to ${type.name}',
                onPressed: onSelected == null ? null : () => onSelected!(type),
                icon: Text(
                  _pieceSymbol(ChessPiece(color, type)),
                  style: const TextStyle(fontSize: 28),
                ),
              ),
            IconButton(
              tooltip: 'Cancel promotion',
              onPressed: onCancel,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GameDetails extends StatelessWidget {
  const _GameDetails({
    required this.model,
    required this.recentHistory,
    required this.compact,
  });

  final ChessModel model;
  final List<ChessMoveRecord> recentHistory;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final whiteCaptured = model.history
        .where((record) => record.capturedPiece?.color == ChessColor.black)
        .map((record) => _pieceSymbol(record.capturedPiece!))
        .join();
    final blackCaptured = model.history
        .where((record) => record.capturedPiece?.color == ChessColor.white)
        .map((record) => _pieceSymbol(record.capturedPiece!))
        .join();
    final moves = recentHistory
        .map((record) {
          final prefix = record.piece.color == ChessColor.white
              ? '${record.fullmoveNumber}. '
              : '';
          return '$prefix${record.notation}';
        })
        .join('  ');
    return SizedBox(
      height: compact ? 38 : 54,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label:
                  'Captured by White: ${whiteCaptured.isEmpty ? 'none' : whiteCaptured}',
              excludeSemantics: true,
              child: Text(
                '♔ ${whiteCaptured.isEmpty ? '—' : whiteCaptured}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Semantics(
              label: 'Move history: ${moves.isEmpty ? 'no moves' : moves}',
              excludeSemantics: true,
              child: Text(
                moves.isEmpty ? 'NO MOVES YET' : moves,
                textAlign: TextAlign.center,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: compact ? 10 : 12,
                ),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              label:
                  'Captured by Black: ${blackCaptured.isEmpty ? 'none' : blackCaptured}',
              excludeSemantics: true,
              child: Text(
                '♚ ${blackCaptured.isEmpty ? '—' : blackCaptured}',
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _pieceSymbol(ChessPiece piece) => switch ((piece.color, piece.type)) {
  (ChessColor.white, ChessPieceType.king) => '♔',
  (ChessColor.white, ChessPieceType.queen) => '♕',
  (ChessColor.white, ChessPieceType.rook) => '♖',
  (ChessColor.white, ChessPieceType.bishop) => '♗',
  (ChessColor.white, ChessPieceType.knight) => '♘',
  (ChessColor.white, ChessPieceType.pawn) => '♙',
  (ChessColor.black, ChessPieceType.king) => '♚',
  (ChessColor.black, ChessPieceType.queen) => '♛',
  (ChessColor.black, ChessPieceType.rook) => '♜',
  (ChessColor.black, ChessPieceType.bishop) => '♝',
  (ChessColor.black, ChessPieceType.knight) => '♞',
  (ChessColor.black, ChessPieceType.pawn) => '♟',
};
