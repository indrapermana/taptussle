import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/match_options.dart';
import 'ludo_controller.dart';
import 'ludo_model.dart';

class LudoBoard extends StatelessWidget {
  const LudoBoard({required this.controller, required this.options, super.key});

  final LudoController controller;
  final MatchOptions options;

  @override
  Widget build(BuildContext context) {
    assert(options.participants.length == controller.model.playerCount);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => ColoredBox(
        color: TapTussleColors.midnight,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 680;
              return Padding(
                padding: EdgeInsets.fromLTRB(10, compact ? 7 : 12, 10, 10),
                child: Column(
                  children: [
                    _TurnBanner(controller: controller, options: options),
                    SizedBox(height: compact ? 7 : 10),
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: _LudoGameBoard(
                            controller: controller,
                            options: options,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 7 : 10),
                    _MatchControls(controller: controller, options: options),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TurnBanner extends StatelessWidget {
  const _TurnBanner({required this.controller, required this.options});

  final LudoController controller;
  final MatchOptions options;

  @override
  Widget build(BuildContext context) {
    final model = controller.model;
    final activePlayer = controller.animationPlayer ?? model.currentPlayer;
    final participant = options.participants[activePlayer];
    final status = model.isFinished
        ? 'FINAL STANDINGS'
        : controller.isAnimating
        ? '${participant.displayName.toUpperCase()} IS MOVING'
        : controller.pendingBotAction == LudoBotAction.rolling
        ? '${participant.displayName.toUpperCase()} IS GETTING READY…'
        : controller.pendingBotAction == LudoBotAction.choosingToken
        ? '${participant.displayName.toUpperCase()} IS CHOOSING…'
        : model.phase == LudoTurnPhase.awaitingMove
        ? 'ROLL ${model.pendingRoll} • CHOOSE A TOKEN'
        : '${participant.displayName.toUpperCase()}’S TURN';

    return ArcadePanel(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      accent: _participantColor(participant.color),
      child: Row(
        children: [
          _LudoToken(participant: participant, size: 27),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              status,
              key: const ValueKey('ludo-status'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Lilita One',
                fontSize: 17,
                letterSpacing: .5,
              ),
            ),
          ),
          if (model.lastRoll case final lastRoll?)
            _DiceFace(value: lastRoll.value),
        ],
      ),
    );
  }
}

class _LudoGameBoard extends StatelessWidget {
  const _LudoGameBoard({required this.controller, required this.options});

  final LudoController controller;
  final MatchOptions options;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final boardSize = math.min(constraints.maxWidth, constraints.maxHeight);
      final cellSize = boardSize / _LudoGeometry.gridSize;
      final tokenSize = (cellSize * .9).clamp(14.0, 31.0);
      final legal = controller.legalTokenIndexes.toSet();
      final activePlayer = controller.model.currentPlayer;

      return Semantics(
        label: 'Ludo board with ${options.participants.length} players',
        child: SizedBox.square(
          dimension: boardSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6FA),
              border: Border.all(color: TapTussleColors.electricBlue, width: 2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x5500D9FF), blurRadius: 14),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                key: const ValueKey('ludo-board'),
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _LudoBoardPainter(
                        participantColors: [
                          for (final participant in options.participants)
                            _participantColor(participant.color),
                        ],
                      ),
                    ),
                  ),
                  for (
                    var player = 0;
                    player < options.participants.length;
                    player++
                  )
                    for (
                      var token = 0;
                      token < LudoModel.tokensPerPlayer;
                      token++
                    )
                      _PositionedToken(
                        key: ValueKey('ludo-token-$player-$token'),
                        playerIndex: player,
                        tokenIndex: token,
                        progress: controller.displayProgress[player][token],
                        participant: options.participants[player],
                        boardSize: boardSize,
                        tokenSize: tokenSize,
                        selectable:
                            player == activePlayer && legal.contains(token),
                        animationDuration:
                            controller.movementStepDuration == Duration.zero
                            ? Duration.zero
                            : Duration(
                                milliseconds: math.max(
                                  70,
                                  (controller
                                              .movementStepDuration
                                              .inMilliseconds *
                                          .72)
                                      .round(),
                                ),
                              ),
                        onTap: () => controller.chooseToken(token),
                      ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PositionedToken extends StatelessWidget {
  const _PositionedToken({
    required this.playerIndex,
    required this.tokenIndex,
    required this.progress,
    required this.participant,
    required this.boardSize,
    required this.tokenSize,
    required this.selectable,
    required this.animationDuration,
    required this.onTap,
    super.key,
  });

  final int playerIndex;
  final int tokenIndex;
  final int progress;
  final MatchParticipant participant;
  final double boardSize;
  final double tokenSize;
  final bool selectable;
  final Duration animationDuration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final center = _LudoGeometry.tokenCenter(
      playerIndex: playerIndex,
      tokenIndex: tokenIndex,
      progress: progress,
      boardSize: boardSize,
    );
    final location = _locationLabel(playerIndex, progress);
    final label =
        '${participant.displayName}, token ${tokenIndex + 1}, $location'
        '${selectable ? ', available to move' : ''}';

    return AnimatedPositioned(
      duration: animationDuration,
      curve: Curves.easeInOut,
      left: center.dx - tokenSize / 2,
      top: center.dy - tokenSize / 2,
      width: tokenSize,
      height: tokenSize,
      child: Semantics(
        button: selectable,
        enabled: selectable,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: selectable ? onTap : null,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 130),
            scale: selectable ? 1.12 : 1,
            child: _LudoToken(
              participant: participant,
              size: tokenSize,
              highlighted: selectable,
            ),
          ),
        ),
      ),
    );
  }

  static String _locationLabel(int player, int progress) {
    if (progress == LudoModel.boxProgress) return 'in the starting box';
    if (progress == LudoModel.finishProgress) return 'at final home';
    if (progress >= LudoModel.homePathStart) {
      return 'on home space ${progress - LudoModel.homePathStart + 1}';
    }
    final absolute =
        (LudoModel.startTrackIndexes[player] + progress) %
        LudoModel.trackLength;
    return 'on track space ${absolute + 1}';
  }
}

class _MatchControls extends StatelessWidget {
  const _MatchControls({required this.controller, required this.options});

  final LudoController controller;
  final MatchOptions options;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Wrap(
          spacing: 6,
          runSpacing: 5,
          children: [
            for (final entry in options.participants.indexed)
              _PlayerBadge(
                participant: entry.$2,
                homeCount: controller.model.tokenProgress[entry.$1]
                    .where((progress) => progress == LudoModel.finishProgress)
                    .length,
                active:
                    !controller.model.isFinished &&
                    controller.model.currentPlayer == entry.$1,
                placement: controller.model.standings.indexOf(entry.$1),
              ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      FilledButton.icon(
        key: const ValueKey('ludo-roll'),
        onPressed: controller.canRoll ? controller.roll : null,
        icon: const Icon(Icons.casino_rounded),
        label: Text(
          controller.isBotTurn || controller.isBotThinking
              ? 'WAIT'
              : controller.model.phase == LudoTurnPhase.awaitingMove
              ? 'PICK'
              : controller.isAnimating
              ? 'MOVING'
              : 'ROLL',
        ),
      ),
    ],
  );
}

class _PlayerBadge extends StatelessWidget {
  const _PlayerBadge({
    required this.participant,
    required this.homeCount,
    required this.active,
    required this.placement,
  });

  final MatchParticipant participant;
  final int homeCount;
  final bool active;
  final int placement;

  @override
  Widget build(BuildContext context) {
    final color = _participantColor(participant.color);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: .18) : const Color(0xFF15283C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? color : const Color(0xFF334B61)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LudoToken(participant: participant, size: 17),
          const SizedBox(width: 5),
          Text(
            placement >= 0
                ? '${_ordinal(placement + 1)} ${participant.displayName}'
                : '${participant.displayName} $homeCount/4',
            key: ValueKey('ludo-player-${participant.displayName}'),
            style: TextStyle(
              color: active ? Colors.white : TapTussleColors.mutedText,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiceFace extends StatelessWidget {
  const _DiceFace({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Last roll $value',
    child: Container(
      key: const ValueKey('ludo-die'),
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
      ),
      child: Text(
        '$value',
        style: const TextStyle(
          color: TapTussleColors.midnight,
          fontFamily: 'Lilita One',
          fontSize: 20,
        ),
      ),
    ),
  );
}

class _LudoToken extends StatelessWidget {
  const _LudoToken({
    required this.participant,
    required this.size,
    this.highlighted = false,
  });

  final MatchParticipant participant;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final color = _participantColor(participant.color);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: highlighted ? TapTussleColors.gold : Colors.white,
          width: highlighted ? 2.5 : 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted ? TapTussleColors.gold : Colors.black54,
            blurRadius: highlighted ? 8 : 3,
            spreadRadius: highlighted ? 1 : 0,
          ),
        ],
      ),
      child: Icon(
        _tokenIcon(participant.token),
        color: Colors.white,
        size: size * .58,
      ),
    );
  }
}

class _LudoBoardPainter extends CustomPainter {
  const _LudoBoardPainter({required this.participantColors});

  final List<Color> participantColors;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _LudoGeometry.gridSize;
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = const Color(0xFF6C7D8E);

    canvas.drawColor(const Color(0xFFE8EDF2), BlendMode.src);
    for (var player = 0; player < 4; player++) {
      final color = player < participantColors.length
          ? participantColors[player]
          : const Color(0xFF708090);
      final quadrant = _LudoGeometry.homeQuadrants[player];
      canvas.drawRect(
        Rect.fromLTWH(
          quadrant.$2 * cell,
          quadrant.$1 * cell,
          6 * cell,
          6 * cell,
        ),
        Paint()..color = color.withValues(alpha: .28),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            (quadrant.$2 + 1) * cell,
            (quadrant.$1 + 1) * cell,
            4 * cell,
            4 * cell,
          ),
          Radius.circular(cell * .55),
        ),
        Paint()..color = Colors.white.withValues(alpha: .82),
      );
    }

    for (final position in _LudoGeometry.track) {
      _drawCell(canvas, position, cell, const Color(0xFFF9FBFD), gridPaint);
    }
    for (var player = 0; player < 4; player++) {
      final color = player < participantColors.length
          ? participantColors[player]
          : const Color(0xFF708090);
      _drawCell(
        canvas,
        _LudoGeometry.track[LudoModel.startTrackIndexes[player]],
        cell,
        color.withValues(alpha: .62),
        gridPaint,
      );
      for (final position in _LudoGeometry.homePaths[player]) {
        _drawCell(
          canvas,
          position,
          cell,
          color.withValues(alpha: .6),
          gridPaint,
        );
      }
    }

    final center = Offset(size.width / 2, size.height / 2);
    final centerRect = Rect.fromCenter(
      center: center,
      width: 3 * cell,
      height: 3 * cell,
    );
    for (var player = 0; player < 4; player++) {
      final color = player < participantColors.length
          ? participantColors[player]
          : const Color(0xFF708090);
      final corners = [
        centerRect.topLeft,
        centerRect.topRight,
        centerRect.bottomRight,
        centerRect.bottomLeft,
      ];
      const wedgeCorners = [(0, 3), (0, 1), (1, 2), (2, 3)];
      final wedge = wedgeCorners[player];
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy)
          ..lineTo(corners[wedge.$1].dx, corners[wedge.$1].dy)
          ..lineTo(corners[wedge.$2].dx, corners[wedge.$2].dy)
          ..close(),
        Paint()..color = color.withValues(alpha: .72),
      );
    }

    final starPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    for (final safeIndex in LudoModel.safeTrackIndexes) {
      final position = _LudoGeometry.track[safeIndex];
      starPainter.text = TextSpan(
        text: '★',
        style: TextStyle(
          color: const Color(0xFF27394A).withValues(alpha: .48),
          fontSize: cell * .58,
        ),
      );
      starPainter.layout();
      starPainter.paint(
        canvas,
        Offset(
          (position.$2 + .5) * cell - starPainter.width / 2,
          (position.$1 + .5) * cell - starPainter.height / 2,
        ),
      );
    }
  }

  void _drawCell(
    Canvas canvas,
    (int, int) position,
    double cell,
    Color color,
    Paint border,
  ) {
    final rect = Rect.fromLTWH(
      position.$2 * cell,
      position.$1 * cell,
      cell,
      cell,
    );
    canvas.drawRect(rect, Paint()..color = color);
    canvas.drawRect(rect, border);
  }

  @override
  bool shouldRepaint(covariant _LudoBoardPainter oldDelegate) =>
      oldDelegate.participantColors != participantColors;
}

abstract final class _LudoGeometry {
  static const int gridSize = 15;

  static const List<(int, int)> track = [
    (6, 1),
    (6, 2),
    (6, 3),
    (6, 4),
    (6, 5),
    (5, 6),
    (4, 6),
    (3, 6),
    (2, 6),
    (1, 6),
    (0, 6),
    (0, 7),
    (0, 8),
    (1, 8),
    (2, 8),
    (3, 8),
    (4, 8),
    (5, 8),
    (6, 9),
    (6, 10),
    (6, 11),
    (6, 12),
    (6, 13),
    (6, 14),
    (7, 14),
    (8, 14),
    (8, 13),
    (8, 12),
    (8, 11),
    (8, 10),
    (8, 9),
    (9, 8),
    (10, 8),
    (11, 8),
    (12, 8),
    (13, 8),
    (14, 8),
    (14, 7),
    (14, 6),
    (13, 6),
    (12, 6),
    (11, 6),
    (10, 6),
    (9, 6),
    (8, 5),
    (8, 4),
    (8, 3),
    (8, 2),
    (8, 1),
    (8, 0),
    (7, 0),
    (6, 0),
  ];

  static const List<List<(int, int)>> homePaths = [
    [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5)],
    [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7)],
    [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9)],
    [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7)],
  ];

  static const List<(int, int)> homeQuadrants = [
    (0, 0),
    (0, 9),
    (9, 9),
    (9, 0),
  ];

  static const List<List<(double, double)>> boxSlots = [
    [(2.0, 2.0), (2.0, 4.0), (4.0, 2.0), (4.0, 4.0)],
    [(2.0, 10.0), (2.0, 12.0), (4.0, 10.0), (4.0, 12.0)],
    [(10.0, 10.0), (10.0, 12.0), (12.0, 10.0), (12.0, 12.0)],
    [(10.0, 2.0), (10.0, 4.0), (12.0, 2.0), (12.0, 4.0)],
  ];

  static Offset tokenCenter({
    required int playerIndex,
    required int tokenIndex,
    required int progress,
    required double boardSize,
  }) {
    final cell = boardSize / gridSize;
    if (progress == LudoModel.boxProgress) {
      final slot = boxSlots[playerIndex][tokenIndex];
      return Offset((slot.$2 + .5) * cell, (slot.$1 + .5) * cell);
    }
    if (progress == LudoModel.finishProgress) {
      const offsets = [(-.26, -.26), (.26, -.26), (.26, .26), (-.26, .26)];
      final offset = offsets[tokenIndex];
      return Offset((7.5 + offset.$1) * cell, (7.5 + offset.$2) * cell);
    }

    final position = progress >= LudoModel.homePathStart
        ? homePaths[playerIndex][progress - LudoModel.homePathStart]
        : track[(LudoModel.startTrackIndexes[playerIndex] + progress) %
              LudoModel.trackLength];
    const overlapOffsets = [(-.16, -.16), (.16, -.16), (.16, .16), (-.16, .16)];
    final overlap = overlapOffsets[tokenIndex];
    return Offset(
      (position.$2 + .5 + overlap.$1) * cell,
      (position.$1 + .5 + overlap.$2) * cell,
    );
  }
}

Color _participantColor(ParticipantColor color) => switch (color) {
  ParticipantColor.mint => const Color(0xFF16BFD6),
  ParticipantColor.coral => TapTussleColors.rivalRed,
  ParticipantColor.gold => TapTussleColors.gold,
  ParticipantColor.violet => const Color(0xFF9B65F5),
};

IconData _tokenIcon(ParticipantToken token) => switch (token) {
  ParticipantToken.circle => Icons.circle,
  ParticipantToken.diamond => Icons.diamond,
  ParticipantToken.triangle => Icons.change_history,
  ParticipantToken.star => Icons.star,
};

String _ordinal(int value) => switch (value) {
  1 => '1ST',
  2 => '2ND',
  3 => '3RD',
  _ => '${value}TH',
};
