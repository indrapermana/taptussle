import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/haptic_service.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'tic_tac_toe_controller.dart';
import 'tic_tac_toe_model.dart';

class TicTacToeView extends StatefulWidget {
  const TicTacToeView({
    required this.session,
    required this.options,
    super.key,
  });

  final MatchSession session;
  final MatchOptions options;

  @override
  State<TicTacToeView> createState() => _TicTacToeViewState();
}

class _TicTacToeViewState extends State<TicTacToeView> {
  late final TicTacToeController controller;
  int _reportedMoves = 0;
  bool _reportedResult = false;
  int? _invalidCell;
  Timer? _invalidTimer;

  @override
  void initState() {
    super.initState();
    controller = TicTacToeController(
      session: widget.session,
      resultRevealDelay: const Duration(milliseconds: 1300),
    )..addListener(_playEffects);
  }

  void _playEffects() {
    final moves = controller.model.moveCount;
    if (moves < _reportedMoves) {
      _reportedMoves = 0;
      _reportedResult = false;
    }
    if (moves <= _reportedMoves) return;
    _reportedMoves = moves;
    if (controller.model.isFinished && !_reportedResult) {
      _reportedResult = true;
      SoundEffects.play(SoundEffect.roundReveal);
    } else {
      SoundEffects.play(SoundEffect.pieceMove);
    }
    HapticEffects.preview();
  }

  void _handleCellTap(int cell) {
    final result = controller.humanMove(cell);
    if (result != TicTacToeMoveResult.occupied) return;
    _invalidTimer?.cancel();
    setState(() => _invalidCell = cell);
    SoundEffects.play(SoundEffect.uiInvalid);
    HapticEffects.preview();
    _invalidTimer = Timer(const Duration(milliseconds: 420), () {
      if (mounted) setState(() => _invalidCell = null);
    });
  }

  @override
  void dispose() {
    _invalidTimer?.cancel();
    controller.removeListener(_playEffects);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => TicTacToeBoard(
      model: controller.model,
      playerLabels: [
        widget.options.playerLabel(0),
        widget.options.playerLabel(1),
      ],
      enabled: controller.acceptsHumanInput,
      statusOverride: controller.isBotThinking ? 'O THINKING…' : null,
      invalidCell: _invalidCell,
      onCellTap: _handleCellTap,
    ),
  );
}

/// Presentational board that maps state to UI and taps to cell indices.
class TicTacToeBoard extends StatelessWidget {
  const TicTacToeBoard({
    required this.model,
    required this.onCellTap,
    this.playerLabels = const ['Player 1', 'Player 2'],
    this.enabled = true,
    this.statusOverride,
    this.invalidCell,
    super.key,
  }) : assert(playerLabels.length == 2);

  final TicTacToeModel model;
  final ValueChanged<int> onCellTap;
  final List<String> playerLabels;
  final bool enabled;
  final String? statusOverride;
  final int? invalidCell;

  static const _warm = Color(0xFFFF7043);
  static const _cool = Color(0xFF29C9FF);
  static const _xAsset = 'assets/games/tic_tac_toe/x_warm.png';
  static const _oAsset = 'assets/games/tic_tac_toe/o_cool.png';

  @override
  Widget build(BuildContext context) {
    final winner = model.winner;
    final status =
        statusOverride ??
        (model.isDraw
            ? 'DRAW!'
            : winner != null
            ? '${playerLabels[winner].toUpperCase()} WINS'
            : '${_markLabel(model.markForPlayer(model.currentPlayer))} TURN');

    return ColoredBox(
      color: const Color(0xFF101A27),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _PlayerBadge(
                      label: playerLabels[0],
                      mark: TicTacToeMark.x,
                      color: _warm,
                      active: !model.isFinished && model.currentPlayer == 0,
                      winner: winner == 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PlayerBadge(
                      label: playerLabels[1],
                      mark: TicTacToeMark.o,
                      color: _cool,
                      active: !model.isFinished && model.currentPlayer == 1,
                      winner: winner == 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Semantics(
                liveRegion: true,
                child: Text(
                  status,
                  key: const ValueKey('tic-tac-toe-status'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: model.isDraw
                        ? Colors.white
                        : winner == 1 ||
                              (!model.isFinished && model.currentPlayer == 1)
                        ? _cool
                        : _warm,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                ),
                            itemCount: TicTacToeModel.cellCount,
                            itemBuilder: (context, cell) => _Cell(
                              cell: cell,
                              mark: model.board[cell],
                              winning:
                                  model.winningLine?.contains(cell) ?? false,
                              draw: model.isDraw,
                              invalid: invalidCell == cell,
                              interactive: enabled && !model.isFinished,
                              enabled:
                                  enabled &&
                                  !model.isFinished &&
                                  model.board[cell] == null,
                              onTap: onCellTap,
                            ),
                          ),
                          if (model.winningLine case final line?)
                            IgnorePointer(
                              child: TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 520),
                                curve: Curves.easeOutBack,
                                builder: (context, progress, _) => CustomPaint(
                                  painter: _WinningLinePainter(
                                    line: line,
                                    color: winner == 0 ? _warm : _cool,
                                    progress: progress,
                                  ),
                                ),
                              ),
                            ),
                          IgnorePointer(
                            child: Center(
                              child: AnimatedScale(
                                scale: model.isDraw ? 1 : 0,
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutBack,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: const Color(0xF21A2740),
                                    borderRadius: BorderRadius.circular(22),
                                    border: Border.all(
                                      color: const Color(0xFFFFD166),
                                      width: 3,
                                    ),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 16,
                                    ),
                                    child: Text(
                                      'DRAW!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _markLabel(TicTacToeMark mark) => switch (mark) {
    TicTacToeMark.x => 'X',
    TicTacToeMark.o => 'O',
  };
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({
    required this.label,
    required this.mark,
    required this.color,
    required this.active,
    required this.winner,
  });

  final String label;
  final TicTacToeMark mark;
  final Color color;
  final bool active;
  final bool winner;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: active || winner ? 1.035 : 1),
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutBack,
    builder: (context, scale, child) =>
        Transform.scale(scale: scale, child: child),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active || winner
            ? color.withValues(alpha: .18)
            : const Color(0xFF182A3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active || winner ? color : const Color(0xFF304253),
          width: active || winner ? 2.5 : 1,
        ),
        boxShadow: active || winner
            ? [BoxShadow(color: color.withValues(alpha: .28), blurRadius: 16)]
            : null,
      ),
      child: Row(
        children: [
          Image.asset(
            mark == TicTacToeMark.x
                ? TicTacToeBoard._xAsset
                : TicTacToeBoard._oAsset,
            width: 34,
            height: 34,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              winner ? '$label wins' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active || winner ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.cell,
    required this.mark,
    required this.winning,
    required this.draw,
    required this.invalid,
    required this.interactive,
    required this.enabled,
    required this.onTap,
  });

  final int cell;
  final TicTacToeMark? mark;
  final bool winning;
  final bool draw;
  final bool invalid;
  final bool interactive;
  final bool enabled;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final markColor = mark == TicTacToeMark.o
        ? TicTacToeBoard._cool
        : TicTacToeBoard._warm;
    final semanticMark = mark == null
        ? 'empty'
        : TicTacToeBoard._markLabel(mark!);
    final semanticLabel = [
      'Cell ${cell + 1}',
      semanticMark,
      if (winning) 'winning cell',
      if (draw) 'draw',
      if (invalid) 'invalid move',
    ].join(', ');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: invalid ? 1 : 0),
      duration: const Duration(milliseconds: 320),
      builder: (context, shake, child) => Transform.translate(
        offset: Offset(math.sin(shake * math.pi * 6) * 7, 0),
        child: child,
      ),
      child: Semantics(
        label: semanticLabel,
        liveRegion: invalid,
        button: true,
        enabled: enabled,
        excludeSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('tic-tac-toe-cell-$cell'),
            borderRadius: BorderRadius.circular(18),
            onTap: interactive ? () => onTap(cell) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: invalid
                    ? const Color(0x4DFF3B30)
                    : winning
                    ? markColor.withValues(alpha: .2)
                    : draw
                    ? const Color(0xFF223346)
                    : const Color(0xFF182A3A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: invalid
                      ? const Color(0xFFFF5A52)
                      : winning
                      ? markColor
                      : const Color(0xFF304253),
                  width: invalid || winning ? 3 : 1.5,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutBack,
                  ),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: mark == null
                    ? const SizedBox.shrink(key: ValueKey('empty'))
                    : Padding(
                        key: ValueKey(mark),
                        padding: const EdgeInsets.all(14),
                        child: Image.asset(
                          mark == TicTacToeMark.x
                              ? TicTacToeBoard._xAsset
                              : TicTacToeBoard._oAsset,
                          fit: BoxFit.contain,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WinningLinePainter extends CustomPainter {
  const _WinningLinePainter({
    required this.line,
    required this.color,
    required this.progress,
  });

  final List<int> line;
  final Color color;
  final double progress;

  Offset _center(int cell, Size size) => Offset(
    (cell % 3 + .5) * size.width / 3,
    (cell ~/ 3 + .5) * size.height / 3,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final start = _center(line.first, size);
    final end = _center(line.last, size);
    final animatedEnd = Offset.lerp(start, end, progress)!;
    canvas.drawLine(
      start,
      animatedEnd,
      Paint()
        ..color = color.withValues(alpha: .32)
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      start,
      animatedEnd,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_WinningLinePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.line != line;
}
