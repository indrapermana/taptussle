import 'package:flutter/material.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'checkers_controller.dart';
import 'checkers_model.dart';

class CheckersView extends StatefulWidget {
  const CheckersView({required this.session, required this.options, super.key});

  final MatchSession session;
  final MatchOptions options;

  @override
  State<CheckersView> createState() => _CheckersViewState();
}

class _CheckersViewState extends State<CheckersView> {
  late final CheckersController controller;

  @override
  void initState() {
    super.initState();
    controller = CheckersController(session: widget.session);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => CheckersBoard(
      model: controller.model,
      selectedSquare: controller.selectedSquare,
      enabled: controller.acceptsInput,
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
    super.key,
  }) : assert(playerLabels.length == 2);

  final CheckersModel model;
  final ValueChanged<int> onSquareTap;
  final int? selectedSquare;
  final List<String> playerLabels;
  final bool enabled;

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
    final status = _statusText(model, playerLabels);

    return ColoredBox(
      color: const Color(0xFF0C1724),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 620;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, compact ? 10 : 18, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _PlayerBadge(
                          label: playerLabels[0],
                          color: playerOneColor,
                          pieces: model.pieceCount(0),
                          active: !model.isFinished && model.currentPlayer == 0,
                          winner: winner == 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PlayerBadge(
                          label: playerLabels[1],
                          color: playerTwoColor,
                          pieces: model.pieceCount(1),
                          active: !model.isFinished && model.currentPlayer == 1,
                          winner: winner == 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      status,
                      key: ValueKey(status),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        color: _statusColor(model),
                        fontSize: compact ? 15 : 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 14),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
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
      return '${labels[model.currentPlayer].toUpperCase()} • CONTINUE CAPTURING';
    }
    final captureRequired = model.legalMoves.any((move) => move.isCapture);
    return '${labels[model.currentPlayer].toUpperCase()}\'S TURN'
        '${captureRequired ? ' • CAPTURE REQUIRED' : ''}';
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
    required this.color,
    required this.pieces,
    required this.active,
    required this.winner,
  });

  final String label;
  final Color color;
  final int pieces;
  final bool active;
  final bool winner;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white70),
          ),
        ),
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
                '$pieces PIECES',
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
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .55),
                    shape: BoxShape.circle,
                  ),
                ),
              if (piece case final piece?) _Piece(piece: piece),
              if (target != null)
                FractionallySizedBox(
                  widthFactor: target!.isCapture ? .62 : .34,
                  heightFactor: target!.isCapture ? .62 : .34,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: target!.isCapture
                          ? Colors.transparent
                          : CheckersBoard._legalTarget,
                      border: target!.isCapture
                          ? Border.all(
                              color: CheckersBoard._legalTarget,
                              width: 4,
                            )
                          : null,
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

class _Piece extends StatelessWidget {
  const _Piece({required this.piece});

  final CheckersPiece piece;

  @override
  Widget build(BuildContext context) {
    final color = piece.player == 0
        ? CheckersBoard.playerOneColor
        : CheckersBoard.playerTwoColor;
    return FractionallySizedBox(
      widthFactor: .72,
      heightFactor: .72,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-.35, -.45),
            colors: [Color.lerp(color, Colors.white, .32)!, color],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: .75),
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 4,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: piece.isKing
            ? const FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
