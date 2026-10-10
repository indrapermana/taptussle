import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/haptic_service.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'checkers_controller.dart';
import 'checkers_model.dart';

class CheckersView extends StatefulWidget {
  const CheckersView({
    required this.session,
    required this.options,
    this.initialModel,
    super.key,
  });

  final MatchSession session;
  final MatchOptions options;
  final CheckersModel? initialModel;

  @override
  State<CheckersView> createState() => _CheckersViewState();
}

class _CheckersViewState extends State<CheckersView> {
  late final CheckersController controller;
  late CheckersModel _observedModel;
  late List<CheckersPiece?> _observedBoard;

  @override
  void initState() {
    super.initState();
    controller = CheckersController(
      session: widget.session,
      model: widget.initialModel,
    )..addListener(_playEffects);
    _observedModel = controller.model;
    _observedBoard = controller.model.board;
  }

  void _playEffects() {
    if (!identical(_observedModel, controller.model)) {
      _observedModel = controller.model;
      _observedBoard = controller.model.board;
      return;
    }
    final board = controller.model.board;
    if (listEquals(board, _observedBoard)) return;

    final previousPieces = _observedBoard.whereType<CheckersPiece>().length;
    final currentPieces = board.whereType<CheckersPiece>().length;
    final previousKings = _observedBoard
        .whereType<CheckersPiece>()
        .where((piece) => piece.isKing)
        .length;
    final currentKings = board
        .whereType<CheckersPiece>()
        .where((piece) => piece.isKing)
        .length;
    _observedBoard = board;

    if (currentKings > previousKings) {
      SoundEffects.play(SoundEffect.levelUp);
      HapticEffects.paddleHit();
    } else if (currentPieces < previousPieces) {
      SoundEffects.play(SoundEffect.boardCapture);
      HapticEffects.paddleHit();
    } else {
      SoundEffects.play(SoundEffect.pieceMove);
      HapticEffects.preview();
    }
  }

  @override
  void dispose() {
    controller.removeListener(_playEffects);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => CheckersBoard(
      model: controller.model,
      controller: controller,
      selectedSquare: controller.selectedSquare,
      enabled: controller.acceptsInput,
      statusOverride: controller.isBotThinking
          ? controller.model.forcedCaptureSquare == null
                ? 'BOT IS THINKING…'
                : 'BOT • CONTINUE CAPTURING…'
          : null,
      playerLabels: [
        widget.options.playerLabel(0),
        widget.options.playerLabel(1),
      ],
      onSquareTap: controller.tapSquare,
    ),
  );
}

/// Responsive, accessible presentation for an American Checkers position.
class CheckersBoard extends StatelessWidget {
  const CheckersBoard({
    required this.model,
    required this.onSquareTap,
    this.selectedSquare,
    this.playerLabels = const ['Player 1', 'Player 2'],
    this.enabled = true,
    this.statusOverride,
    this.controller,
    super.key,
  }) : assert(playerLabels.length == 2);

  final CheckersModel model;
  final ValueChanged<int> onSquareTap;
  final int? selectedSquare;
  final List<String> playerLabels;
  final bool enabled;
  final String? statusOverride;
  final CheckersController? controller;

  static const playerOneColor = Color(0xFFFF664F);
  static const playerTwoColor = Color(0xFF35C8FF);
  static const _darkSquare = Color(0xFF25364D);
  static const _lightSquare = Color(0xFFE7D7B9);
  static const _boardFrame = Color(0xFF101A27);
  static const _legalTarget = Color(0xFF7EE7A8);
  static const _selected = Color(0xFFFFD54A);

  @override
  Widget build(BuildContext context) {
    final legalTargets = {
      for (final move
          in selectedSquare == null
              ? const <CheckersMove>[]
              : model.legalMovesFrom(selectedSquare!))
        move.to: move,
    };
    final movableSquares = model.legalMoves.map((move) => move.from).toSet();
    final winner = model.winner;
    final status = statusOverride ?? _statusText(model, playerLabels);

    return ColoredBox(
      color: const Color(0xFF0C1724),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 620;
            return Padding(
              padding: EdgeInsets.fromLTRB(6, compact ? 6 : 10, 6, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _PlayerBadge(
                          label: playerLabels[0],
                          player: 0,
                          color: playerOneColor,
                          pieces: model.pieceCount(0),
                          active: !model.isFinished && model.currentPlayer == 0,
                          winner: winner == 0,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _PlayerBadge(
                          label: playerLabels[1],
                          player: 1,
                          color: playerTwoColor,
                          pieces: model.pieceCount(1),
                          active: !model.isFinished && model.currentPlayer == 1,
                          winner: winner == 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 5 : 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      status,
                      key: ValueKey(status),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        color: _statusColor(model),
                        fontSize: compact ? 14 : 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 5 : 8),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            key: const ValueKey('checkers-board'),
                            decoration: BoxDecoration(
                              color: _boardFrame,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .16),
                                width: 4,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Column(
                                children: [
                                  for (
                                    var row = 0;
                                    row < CheckersModel.boardSize;
                                    row++
                                  )
                                    Expanded(
                                      child: Row(
                                        children: [
                                          for (
                                            var column = 0;
                                            column < CheckersModel.boardSize;
                                            column++
                                          )
                                            Expanded(
                                              child: _BoardSquare(
                                                square: CheckersModel.square(
                                                  row,
                                                  column,
                                                ),
                                                piece:
                                                    model
                                                        .board[CheckersModel.square(
                                                      row,
                                                      column,
                                                    )],
                                                playable: (row + column).isOdd,
                                                selected:
                                                    selectedSquare ==
                                                    CheckersModel.square(
                                                      row,
                                                      column,
                                                    ),
                                                movable: movableSquares
                                                    .contains(
                                                      CheckersModel.square(
                                                        row,
                                                        column,
                                                      ),
                                                    ),
                                                target:
                                                    legalTargets[CheckersModel.square(
                                                      row,
                                                      column,
                                                    )],
                                                enabled: enabled,
                                                playerLabels: playerLabels,
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
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _statusText(CheckersModel model, List<String> labels) {
    if (model.isDraw) {
      return switch (model.drawReason) {
        CheckersDrawReason.threefoldRepetition => 'DRAW • REPEATED POSITION',
        CheckersDrawReason.noProgress => 'DRAW • NO PROGRESS',
        null => 'DRAW',
      };
    }
    if (model.winner case final winner?) {
      return '${labels[winner].toUpperCase()} WINS';
    }
    if (model.forcedCaptureSquare != null) {
      return '${labels[model.currentPlayer].toUpperCase()}: KEEP JUMPING!';
    }
    final captureRequired = model.legalMoves.any((move) => move.isCapture);
    return captureRequired
        ? '${labels[model.currentPlayer].toUpperCase()}: JUMP A PIECE!'
        : '${labels[model.currentPlayer].toUpperCase()}: PICK A PIECE';
  }

  static Color _statusColor(CheckersModel model) {
    if (model.isDraw) return Colors.white;
    final player = model.winner ?? model.currentPlayer;
    return player == 0 ? playerOneColor : playerTwoColor;
  }
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({
    required this.label,
    required this.player,
    required this.color,
    required this.pieces,
    required this.active,
    required this.winner,
  });

  final String label;
  final int player;
  final Color color;
  final int pieces;
  final bool active;
  final bool winner;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: active || winner
          ? color.withValues(alpha: .15)
          : const Color(0xFF182A3A),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: active || winner ? color : const Color(0xFF304253),
        width: active || winner ? 2 : 1,
      ),
    ),
    child: Row(
      children: [
        _PieceMark(color: color, player: player),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                winner ? '$label wins' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '$pieces LEFT',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .7),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _BoardSquare extends StatelessWidget {
  const _BoardSquare({
    required this.square,
    required this.piece,
    required this.playable,
    required this.selected,
    required this.movable,
    required this.target,
    required this.enabled,
    required this.playerLabels,
    required this.onTap,
  });

  final int square;
  final CheckersPiece? piece;
  final bool playable;
  final bool selected;
  final bool movable;
  final CheckersMove? target;
  final bool enabled;
  final List<String> playerLabels;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final row = CheckersModel.rowOf(square);
    final column = CheckersModel.columnOf(square);
    final canTap =
        enabled && playable && (movable || selected || target != null);
    final semanticLabel = [
      'Row ${row + 1}, column ${column + 1}',
      if (piece == null) 'empty' else playerLabels[piece!.player],
      if (piece != null) piece!.isKing ? 'king' : 'piece',
      if (selected) 'selected',
      if (target != null) target!.isCapture ? 'capture target' : 'legal target',
      if (movable && !selected) 'movable',
    ].join(', ');

    return Semantics(
      label: semanticLabel,
      button: playable,
      enabled: canTap,
      excludeSemantics: true,
      child: Material(
        color: playable
            ? CheckersBoard._darkSquare
            : CheckersBoard._lightSquare,
        child: InkWell(
          key: ValueKey('checkers-square-$square'),
          onTap: canTap ? () => onTap(square) : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (selected)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: CheckersBoard._selected,
                        width: 4,
                      ),
                    ),
                  ),
                ),
              if (movable && !selected && target == null)
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: CheckersBoard._selected,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 4),
                    ],
                  ),
                ),
              if (piece case final piece?)
                _Piece(piece: piece, selected: selected),
              if (target != null)
                _MoveTargetIndicator(isCapture: target!.isCapture),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoveTargetIndicator extends StatelessWidget {
  const _MoveTargetIndicator({required this.isCapture});

  final bool isCapture;

  @override
  Widget build(BuildContext context) {
    final color = isCapture
        ? CheckersBoard._selected
        : CheckersBoard._legalTarget;
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: .78), width: 2),
          ),
          child: Center(
            child: Icon(
              isCapture ? Icons.bolt_rounded : Icons.arrow_forward_rounded,
              color: color.withValues(alpha: .9),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _Piece extends StatelessWidget {
  const _Piece({required this.piece, required this.selected});

  final CheckersPiece piece;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = piece.player == 0
        ? CheckersBoard.playerOneColor
        : CheckersBoard.playerTwoColor;
    return AnimatedScale(
      scale: selected ? 1.1 : 1,
      duration: const Duration(milliseconds: 160),
      child: FractionallySizedBox(
        widthFactor: .82,
        heightFactor: .82,
        child: Material(
          elevation: 5,
          shadowColor: Colors.black87,
          color: color,
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: Colors.white.withValues(alpha: .9),
              width: 2,
            ),
          ),
          child: Ink(
            decoration: ShapeDecoration(
              shape: BeveledRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(color, Colors.white, .42)!,
                  color,
                  Color.lerp(color, Colors.black, .22)!,
                ],
              ),
            ),
            child: Center(
              child: Icon(
                piece.isKing
                    ? Icons.workspace_premium_rounded
                    : piece.player == 0
                    ? Icons.local_fire_department_rounded
                    : Icons.auto_awesome_rounded,
                color: Colors.white,
                size: piece.isKing ? 27 : 23,
                shadows: const [
                  Shadow(
                    color: Colors.black45,
                    blurRadius: 3,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PieceMark extends StatelessWidget {
  const _PieceMark({required this.color, required this.player});

  final Color color;
  final int player;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 22,
    height: 22,
    child: Material(
      color: color,
      shape: BeveledRectangleBorder(
        borderRadius: BorderRadius.circular(5),
        side: const BorderSide(color: Colors.white70),
      ),
      child: Icon(
        player == 0
            ? Icons.local_fire_department_rounded
            : Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 14,
      ),
    ),
  );
}
