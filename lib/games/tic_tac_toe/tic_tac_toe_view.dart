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

  @override
  void initState() {
    super.initState();
    controller = TicTacToeController(session: widget.session)
      ..addListener(_playEffects);
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
      SoundEffects.play(SoundEffect.result);
    } else {
      SoundEffects.play(SoundEffect.click);
    }
    HapticEffects.preview();
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
    builder: (context, _) => TicTacToeBoard(
      model: controller.model,
      playerLabels: [
        widget.options.playerLabel(0),
        widget.options.playerLabel(1),
      ],
      enabled: controller.acceptsHumanInput,
      statusOverride: controller.isBotThinking ? 'BOT IS THINKING… • O' : null,
      onCellTap: controller.humanMove,
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
    super.key,
  }) : assert(playerLabels.length == 2);

  final TicTacToeModel model;
  final ValueChanged<int> onCellTap;
  final List<String> playerLabels;
  final bool enabled;
  final String? statusOverride;

  static const _mint = Color(0xFF9DF5CF);
  static const _coral = Color(0xFFFF968A);

  @override
  Widget build(BuildContext context) {
    final winner = model.winner;
    final status =
        statusOverride ??
        (model.isDraw
            ? 'DRAW • BOARD FULL'
            : winner != null
            ? '${playerLabels[winner].toUpperCase()} WINS'
            : '${playerLabels[model.currentPlayer].toUpperCase()}\'S TURN • '
                  '${_markLabel(model.markForPlayer(model.currentPlayer))}');

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
                      color: _mint,
                      active: !model.isFinished && model.currentPlayer == 0,
                      winner: winner == 0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PlayerBadge(
                      label: playerLabels[1],
                      mark: TicTacToeMark.o,
                      color: _coral,
                      active: !model.isFinished && model.currentPlayer == 1,
                      winner: winner == 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                status,
                key: const ValueKey('tic-tac-toe-status'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: model.isDraw
                      ? Colors.white
                      : winner == 1 ||
                            (!model.isFinished && model.currentPlayer == 1)
                      ? _coral
                      : _mint,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: GridView.builder(
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
                          winning: model.winningLine?.contains(cell) ?? false,
                          draw: model.isDraw,
                          enabled:
                              enabled &&
                              !model.isFinished &&
                              model.board[cell] == null,
                          onTap: onCellTap,
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
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: active || winner
          ? color.withValues(alpha: .14)
          : const Color(0xFF182A3A),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: active || winner ? color : const Color(0xFF304253),
        width: active || winner ? 2 : 1,
      ),
    ),
    child: Row(
      children: [
        Text(
          TicTacToeBoard._markLabel(mark),
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            winner ? '$label wins' : label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.cell,
    required this.mark,
    required this.winning,
    required this.draw,
    required this.enabled,
    required this.onTap,
  });

  final int cell;
  final TicTacToeMark? mark;
  final bool winning;
  final bool draw;
  final bool enabled;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final markColor = mark == TicTacToeMark.o
        ? TicTacToeBoard._coral
        : TicTacToeBoard._mint;
    final semanticMark = mark == null
        ? 'empty'
        : TicTacToeBoard._markLabel(mark!);
    final semanticLabel = [
      'Cell ${cell + 1}',
      semanticMark,
      if (winning) 'winning cell',
      if (draw) 'draw',
    ].join(', ');

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('tic-tac-toe-cell-$cell'),
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? () => onTap(cell) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: winning
                  ? markColor.withValues(alpha: .2)
                  : draw
                  ? const Color(0xFF223346)
                  : const Color(0xFF182A3A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: winning ? markColor : const Color(0xFF304253),
                width: winning ? 3 : 1.5,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                mark == null ? '' : TicTacToeBoard._markLabel(mark!),
                style: TextStyle(
                  color: markColor,
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
