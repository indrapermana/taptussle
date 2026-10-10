import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/haptic_service.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'snakes_and_ladders_controller.dart';
import 'snakes_and_ladders_model.dart';

class SnakesAndLaddersView extends StatefulWidget {
  const SnakesAndLaddersView({
    required this.session,
    required this.options,
    super.key,
  });

  final MatchSession session;
  final MatchOptions options;

  @override
  State<SnakesAndLaddersView> createState() => _SnakesAndLaddersViewState();
}

class _SnakesAndLaddersViewState extends State<SnakesAndLaddersView> {
  late final SnakesAndLaddersController controller;
  SnakesAndLaddersTurn? _observedTurn;
  bool _wasAnimating = false;

  @override
  void initState() {
    super.initState();
    controller = SnakesAndLaddersController(
      session: widget.session,
      diceRollDuration: const Duration(milliseconds: 650),
      movementStepDuration: const Duration(milliseconds: 220),
    )..addListener(_playEffects);
  }

  void _playEffects() {
    final turn = controller.model.lastTurn;
    if (turn == null) {
      _observedTurn = null;
    } else if (!identical(turn, _observedTurn)) {
      _observedTurn = turn;
      SoundEffects.play(SoundEffect.diceRoll);
      HapticEffects.preview();
    }

    if (_wasAnimating && !controller.isAnimating) {
      final turn = controller.model.lastTurn!;
      switch (turn.transitionType) {
        case BoardTransitionType.none:
          SoundEffects.play(
            turn.wasOversized ? SoundEffect.uiInvalid : SoundEffect.pieceMove,
          );
        case BoardTransitionType.ladder:
          SoundEffects.play(SoundEffect.levelUp);
          HapticEffects.preview();
        case BoardTransitionType.snake:
          SoundEffects.play(SoundEffect.impactSoft);
          HapticEffects.paddleHit();
      }
    }
    _wasAnimating = controller.isAnimating;
  }

  @override
  void dispose() {
    controller.removeListener(_playEffects);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SnakesAndLaddersBoard(controller: controller, options: widget.options);
}

class SnakesAndLaddersBoard extends StatelessWidget {
  const SnakesAndLaddersBoard({
    required this.controller,
    required this.options,
    super.key,
  });

  final SnakesAndLaddersController controller;
  final MatchOptions options;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => ColoredBox(
      color: const Color(0xFF101A27),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 650;
            return Padding(
              padding: EdgeInsets.fromLTRB(12, compact ? 8 : 14, 12, 14),
              child: Column(
                children: [
                  _TurnBanner(controller: controller, options: options),
                  SizedBox(height: compact ? 4 : 7),
                  _DiceTray(controller: controller),
                  SizedBox(height: compact ? 4 : 7),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _GameBoard(
                          positions: controller.displayPositions,
                          participants: options.participants,
                          movementDuration: controller.movementStepDuration,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  _RollControls(controller: controller, options: options),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _TurnBanner extends StatelessWidget {
  const _TurnBanner({required this.controller, required this.options});

  final SnakesAndLaddersController controller;
  final MatchOptions options;

  @override
  Widget build(BuildContext context) {
    final player = controller.highlightedPlayer;
    final participant = options.participants[player];
    final status = controller.isRollingDice
        ? '${participant.displayName.toUpperCase()} IS ROLLING…'
        : controller.isAnimating
        ? '${participant.displayName.toUpperCase()} IS MOVING'
        : controller.isBotThinking
        ? '${participant.displayName.toUpperCase()} IS THINKING…'
        : '${participant.displayName.toUpperCase()}’S TURN';
    return ArcadePanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _Token(participant: participant, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status,
              key: const ValueKey('snakes-current-turn'),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Lilita One',
                fontSize: 18,
                letterSpacing: .7,
              ),
            ),
          ),
          Text(
            controller.lastRoll == null
                ? 'ROLL —'
                : 'ROLL ${controller.lastRoll}',
            key: const ValueKey('snakes-last-roll'),
            style: const TextStyle(
              color: TapTussleColors.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameBoard extends StatelessWidget {
  const _GameBoard({
    required this.positions,
    required this.participants,
    required this.movementDuration,
  });

  final List<int> positions;
  final List<MatchParticipant> participants;
  final Duration movementDuration;

  @override
  Widget build(BuildContext context) {
    final visualSquares = SnakesAndLaddersModel.serpentineRows.reversed
        .expand((row) => row)
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, constraints.maxHeight);
        final cell = size / 8;
        return SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: TapTussleColors.electricBlue, width: 2),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Color(0x6600D9FF), blurRadius: 16),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                key: const ValueKey('snakes-board'),
                children: [
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 8,
                        ),
                    itemCount: 64,
                    itemBuilder: (context, index) {
                      final square = visualSquares[index];
                      final destination =
                          SnakesAndLaddersModel.standardTransitions[square];
                      final tokens = [
                        for (final entry in positions.indexed)
                          if (entry.$2 == square) entry.$1,
                      ];
                      return _BoardCell(
                        square: square,
                        destination: destination,
                        tokenIndexes: tokens,
                        participants: participants,
                      );
                    },
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        key: const ValueKey('snakes-board-features'),
                        painter: _BoardFeaturesPainter(
                          transitions:
                              SnakesAndLaddersModel.standardTransitions,
                        ),
                      ),
                    ),
                  ),
                  for (var square = 1; square <= 64; square++)
                    _SquareNumber(square: square, cell: cell),
                  for (final player in positions.indexed)
                    if (player.$2 > 0)
                      _MovingToken(
                        key: ValueKey('snakes-token-${player.$1}'),
                        playerIndex: player.$1,
                        square: player.$2,
                        positions: positions,
                        participant: participants[player.$1],
                        cell: cell,
                        duration: movementDuration,
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Offset _squareCenter(int square, double cell) {
  final rowFromBottom = (square - 1) ~/ 8;
  final offset = (square - 1) % 8;
  final column = rowFromBottom.isEven ? offset : 7 - offset;
  return Offset((column + .5) * cell, (7 - rowFromBottom + .5) * cell);
}

class _BoardFeaturesPainter extends CustomPainter {
  const _BoardFeaturesPainter({required this.transitions});

  final Map<int, int> transitions;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 8;
    var ladderIndex = 0;
    var snakeIndex = 0;
    for (final entry in transitions.entries) {
      final from = _squareCenter(entry.key, cell);
      final to = _squareCenter(entry.value, cell);
      if (entry.value > entry.key) {
        _paintLadder(canvas, from, to, cell, ladderIndex++);
      } else {
        _paintSnake(canvas, from, to, cell, snakeIndex++);
      }
    }
  }

  void _paintLadder(
    Canvas canvas,
    Offset from,
    Offset to,
    double cell,
    int index,
  ) {
    final delta = to - from;
    final distance = delta.distance;
    final direction = delta / distance;
    final normal = Offset(-direction.dy, direction.dx);
    final halfWidth = cell * .18;
    final railPaint = Paint()
      ..color = const Color(0xFFFFA52E)
      ..strokeWidth = cell * .12
      ..strokeCap = StrokeCap.round;
    final outlinePaint = Paint()
      ..color = const Color(0xFF8A4319)
      ..strokeWidth = cell * .18
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final offset = normal * halfWidth * side;
      canvas.drawLine(from + offset, to + offset, outlinePaint);
      canvas.drawLine(from + offset, to + offset, railPaint);
    }
    const rungColors = [
      Color(0xFFFF5454),
      Color(0xFF16BDEC),
      Color(0xFFFFD43B),
      Color(0xFF65C94D),
    ];
    final rungCount = math.max(3, (distance / (cell * .48)).round());
    for (var rung = 1; rung < rungCount; rung++) {
      final center = from + direction * (distance * rung / rungCount);
      final rungPaint = Paint()
        ..color = rungColors[(rung + index) % rungColors.length]
        ..strokeWidth = cell * .1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center - normal * halfWidth,
        center + normal * halfWidth,
        rungPaint,
      );
    }
  }

  void _paintSnake(
    Canvas canvas,
    Offset from,
    Offset to,
    double cell,
    int index,
  ) {
    const colors = [
      Color(0xFF46C94B),
      Color(0xFFFF6B55),
      Color(0xFF9A68E8),
      Color(0xFF24B7D8),
      Color(0xFFFFB52E),
    ];
    final delta = to - from;
    final distance = delta.distance;
    final direction = delta / distance;
    final normal = Offset(-direction.dy, direction.dx);
    final wave = cell * (index.isEven ? .5 : -.5);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(
        (from + direction * distance * .28 + normal * wave).dx,
        (from + direction * distance * .28 + normal * wave).dy,
        (from + direction * distance * .68 - normal * wave).dx,
        (from + direction * distance * .68 - normal * wave).dy,
        to.dx,
        to.dy,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x66000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * .34
        ..strokeCap = StrokeCap.round,
    );
    final bodyColor = colors[index % colors.length];
    canvas.drawPath(
      path,
      Paint()
        ..color = bodyColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * .26
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: .28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * .055
        ..strokeCap = StrokeCap.round,
    );

    final head = from;
    canvas.drawCircle(
      head,
      cell * .23,
      Paint()
        ..color = bodyColor
        ..style = PaintingStyle.fill,
    );
    final eyeLine = normal * cell * .09;
    final eyeForward = direction * cell * .06;
    for (final side in [-1.0, 1.0]) {
      final eye = head - eyeForward + eyeLine * side;
      canvas.drawCircle(eye, cell * .06, Paint()..color = Colors.white);
      canvas.drawCircle(
        eye - direction * cell * .012,
        cell * .027,
        Paint()..color = const Color(0xFF14233D),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BoardFeaturesPainter oldDelegate) =>
      oldDelegate.transitions != transitions;
}

class _SquareNumber extends StatelessWidget {
  const _SquareNumber({required this.square, required this.cell});

  final int square;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final center = _squareCenter(square, cell);
    return Positioned(
      left: center.dx - cell / 2 + 2,
      top: center.dy - cell / 2 + 2,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xE6FFFFFF),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            child: Text(
              '$square',
              style: TextStyle(
                color: const Color(0xFF14233D),
                fontSize: math.max(8, cell * .2),
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MovingToken extends StatelessWidget {
  const _MovingToken({
    required this.playerIndex,
    required this.square,
    required this.positions,
    required this.participant,
    required this.cell,
    required this.duration,
    super.key,
  });

  final int playerIndex;
  final int square;
  final List<int> positions;
  final MatchParticipant participant;
  final double cell;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final center = _squareCenter(square, cell);
    final companions = [
      for (final entry in positions.indexed)
        if (entry.$2 == square) entry.$1,
    ];
    final slot = companions.indexOf(playerIndex);
    final tokenSize = cell * .55;
    final offset = switch (slot) {
      1 => Offset(cell * .18, 0),
      2 => Offset(0, cell * .18),
      3 => Offset(cell * .18, cell * .18),
      _ => Offset.zero,
    };
    return AnimatedPositioned(
      duration: duration,
      curve: Curves.easeInOut,
      left: center.dx - tokenSize / 2 + offset.dx - cell * .09,
      top: center.dy - tokenSize / 2 + offset.dy - cell * .09,
      width: tokenSize,
      height: tokenSize,
      child: Semantics(
        label: '${participant.displayName} on square $square',
        child: _Token(participant: participant, size: tokenSize),
      ),
    );
  }
}

class _BoardCell extends StatelessWidget {
  const _BoardCell({
    required this.square,
    required this.destination,
    required this.tokenIndexes,
    required this.participants,
  });

  final int square;
  final int? destination;
  final List<int> tokenIndexes;
  final List<MatchParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final isLadder = destination != null && destination! > square;
    final row = (square - 1) ~/ 8;
    final base = (row + square).isEven;
    const rowColors = <Color>[
      Color(0xFFFFE3A1),
      Color(0xFFBCEEFF),
      Color(0xFFFFC9D8),
      Color(0xFFCDEFC2),
    ];
    final tileColor = rowColors[row % rowColors.length];
    return Semantics(
      label: _semanticsLabel(isLadder),
      child: DecoratedBox(
        key: ValueKey('snakes-square-$square'),
        decoration: BoxDecoration(
          color: base ? tileColor : Color.lerp(tileColor, Colors.white, .34),
          border: Border.all(color: const Color(0x5527465E), width: .65),
        ),
        child: Stack(
          children: [
            if (square == 64)
              const Positioned.fill(
                child: Center(
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xB3F5A623),
                    size: 30,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _semanticsLabel(bool isLadder) {
    final feature = destination == null
        ? ''
        : isLadder
        ? ', ladder to $destination'
        : ', snake to $destination';
    final occupants = tokenIndexes.isEmpty
        ? ''
        : ', ${tokenIndexes.map((index) => participants[index].displayName).join(', ')}';
    return 'Square $square$feature$occupants';
  }
}

class _RollControls extends StatelessWidget {
  const _RollControls({required this.controller, required this.options});

  final SnakesAndLaddersController controller;
  final MatchOptions options;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 10,
    runSpacing: 5,
    children: [
      for (final entry in options.participants.indexed)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Token(participant: entry.$2, size: 18),
            const SizedBox(width: 4),
            Text(
              '${entry.$2.displayName}: ${controller.displayPositions[entry.$1] == 0 ? 'START' : controller.displayPositions[entry.$1]}',
              style: const TextStyle(
                color: TapTussleColors.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
    ],
  );
}

class _DiceTray extends StatelessWidget {
  const _DiceTray({required this.controller});

  final SnakesAndLaddersController controller;

  @override
  Widget build(BuildContext context) {
    final face = controller.displayDieValue ?? 1;
    return Semantics(
      label: controller.isRollingDice ? 'Dice rolling' : 'Dice shows $face',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox.square(
            dimension: 58,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 85),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: Tween<double>(begin: -.16, end: 0).animate(animation),
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: _DiceFace(key: ValueKey('snakes-die-$face'), value: face),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            key: const ValueKey('snakes-roll'),
            onPressed: controller.canRoll ? controller.roll : null,
            icon: const Icon(Icons.casino_rounded),
            label: Text(
              controller.isRollingDice
                  ? 'ROLLING…'
                  : controller.isBotThinking
                  ? 'WAIT'
                  : 'ROLL DICE',
            ),
          ),
        ],
      ),
    );
  }
}

class _DiceFace extends StatelessWidget {
  const _DiceFace({required this.value, super.key});

  final int value;

  @override
  Widget build(BuildContext context) {
    final pips = switch (value) {
      1 => const [Alignment.center],
      2 => const [Alignment.topLeft, Alignment.bottomRight],
      3 => const [Alignment.topLeft, Alignment.center, Alignment.bottomRight],
      4 => const [
        Alignment.topLeft,
        Alignment.topRight,
        Alignment.bottomLeft,
        Alignment.bottomRight,
      ],
      5 => const [
        Alignment.topLeft,
        Alignment.topRight,
        Alignment.center,
        Alignment.bottomLeft,
        Alignment.bottomRight,
      ],
      _ => const [
        Alignment.topLeft,
        Alignment.centerLeft,
        Alignment.bottomLeft,
        Alignment.topRight,
        Alignment.centerRight,
        Alignment.bottomRight,
      ],
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFFFB62E), width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x6600D9FF), blurRadius: 9, spreadRadius: 1),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Stack(
          children: [
            for (final alignment in pips)
              Align(
                alignment: alignment,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFF17233D),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Token extends StatelessWidget {
  const _Token({required this.participant, required this.size});

  final MatchParticipant participant;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _participantColor(participant.color),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: size > 20 ? 2 : 1),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3)],
    ),
    child: Icon(
      _tokenIcon(participant.token),
      color: Colors.white,
      size: size * .62,
    ),
  );
}

Color _participantColor(ParticipantColor color) => switch (color) {
  ParticipantColor.mint => TapTussleColors.electricBlue,
  ParticipantColor.coral => TapTussleColors.rivalRed,
  ParticipantColor.gold => TapTussleColors.gold,
  ParticipantColor.violet => const Color(0xFFB26CFF),
};

IconData _tokenIcon(ParticipantToken token) => switch (token) {
  ParticipantToken.circle => Icons.circle,
  ParticipantToken.diamond => Icons.diamond,
  ParticipantToken.triangle => Icons.change_history,
  ParticipantToken.star => Icons.star,
};
