import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../core/haptic_service.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'slither_simulation.dart';

enum SlitherArenaEdge { left, top, right, bottom }

/// Flame rendering and timing adapter over the pure [SlitherSimulation].
class SlitherSnakesGame extends Game {
  SlitherSnakesGame({
    required this.session,
    this.seed = 1601,
    this.config = const SlitherSimulationConfig(),
    SlitherSimulation? simulation,
  }) : simulation = simulation ?? SlitherSimulation(seed: seed, config: config);

  final MatchSession session;
  final int seed;
  final SlitherSimulationConfig config;
  SlitherSimulation simulation;
  var cameraCenter = const SlitherPoint(0, 0);
  bool _stopped = false;
  bool _resultReported = false;
  int _reportedPlayerFood = 0;
  int _reportedAliveOpponents = -1;
  static const double worldScale = .82;

  void reset({int round = 0}) {
    simulation = SlitherSimulation(seed: seed + round, config: config);
    cameraCenter = simulation.player.head;
    _resultReported = false;
    _reportedPlayerFood = 0;
    _reportedAliveOpponents = config.aiCount;
  }

  void stopMatch() {
    _stopped = true;
    simulation.steerInDirection(null);
    pauseEngine();
  }

  void clearSteering() => simulation.steerInDirection(null);

  void steerFromScreen(Offset screenPosition) {
    if (_stopped || session.phase != MatchPhase.playing) return;
    final direction = screenPosition - Offset(size.x / 2, size.y / 2);
    if (direction.distance < 4) return;
    simulation.steerInDirection(atan2(direction.dy, direction.dx));
  }

  SlitherPoint screenToWorld(Offset screenPosition) => SlitherPoint(
    (screenPosition.dx - size.x / 2) / worldScale + cameraCenter.x,
    (screenPosition.dy - size.y / 2) / worldScale + cameraCenter.y,
  );

  Offset worldToScreen(SlitherPoint worldPosition) => Offset(
    (worldPosition.x - cameraCenter.x) * worldScale + size.x / 2,
    (worldPosition.y - cameraCenter.y) * worldScale + size.y / 2,
  );

  Rect get visibleWorldBounds => Rect.fromCenter(
    center: Offset(cameraCenter.x, cameraCenter.y),
    width: size.x / worldScale,
    height: size.y / worldScale,
  );

  Rect get minimapRect => Rect.fromLTWH(size.x - 92, size.y - 82, 80, 60);

  Set<SlitherArenaEdge> get nearbyArenaEdges {
    const warningDistance = 280.0;
    final head = simulation.player.head;
    return {
      if (head.x < warningDistance) SlitherArenaEdge.left,
      if (head.y < warningDistance) SlitherArenaEdge.top,
      if (head.x > simulation.config.arenaWidth - warningDistance)
        SlitherArenaEdge.right,
      if (head.y > simulation.config.arenaHeight - warningDistance)
        SlitherArenaEdge.bottom,
    };
  }

  @override
  Color backgroundColor() => const Color(0xFF071521);

  @override
  void update(double dt) {
    if (_stopped || session.phase != MatchPhase.playing) return;
    if (_reportedAliveOpponents < 0) {
      _reportedPlayerFood = simulation.player.foodEaten;
      _reportedAliveOpponents = simulation.opponents
          .where((snake) => snake.alive)
          .length;
    }
    simulation.update(dt);
    _updateCamera();
    _publishSimulationEffects();
    if (simulation.isGameOver) {
      SoundEffects.play(SoundEffect.snakeCrash);
      HapticEffects.paddleHit();
      _publishResult();
    }
  }

  void _publishSimulationEffects() {
    if (simulation.player.foodEaten > _reportedPlayerFood) {
      _reportedPlayerFood = simulation.player.foodEaten;
      SoundEffects.play(SoundEffect.snakeEat);
      HapticEffects.preview();
    }
    final aliveOpponents = simulation.opponents
        .where((snake) => snake.alive)
        .length;
    if (aliveOpponents < _reportedAliveOpponents) {
      SoundEffects.play(SoundEffect.snakeCrash);
      HapticEffects.paddleHit();
    }
    _reportedAliveOpponents = aliveOpponents;
  }

  void _publishResult() {
    if (_resultReported || session.phase != MatchPhase.playing) return;
    _resultReported = true;
    final survivalMilliseconds = (simulation.survivalTime * 1000).round();
    session.reportCompletion(
      scores: [simulation.score],
      details:
          'Score ${simulation.score} • Survived ${_formatSurvival(survivalMilliseconds)}',
      recordMetrics: {
        'score': simulation.score,
        'survivalTime': survivalMilliseconds,
      },
    );
  }

  String _formatSurvival(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    final tenths = duration.inMilliseconds.remainder(1000) ~/ 100;
    return minutes > 0
        ? '$minutes:${seconds.toString().padLeft(2, '0')}'
        : '$seconds.${tenths}s';
  }

  void _updateCamera() {
    final halfWidth = size.x / (2 * worldScale);
    final halfHeight = size.y / (2 * worldScale);
    final arenaWidth = simulation.config.arenaWidth;
    final arenaHeight = simulation.config.arenaHeight;
    cameraCenter = SlitherPoint(
      arenaWidth <= halfWidth * 2
          ? arenaWidth / 2
          : simulation.player.head.x.clamp(halfWidth, arenaWidth - halfWidth),
      arenaHeight <= halfHeight * 2
          ? arenaHeight / 2
          : simulation.player.head.y.clamp(
              halfHeight,
              arenaHeight - halfHeight,
            ),
    );
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _updateCamera();
  }

  @override
  void render(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0) return;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(worldScale);
    canvas.translate(-cameraCenter.x, -cameraCenter.y);
    _drawArena(canvas);
    final visibleBounds = visibleWorldBounds.inflate(40);
    _drawFood(canvas, visibleBounds);
    final leader = simulation.leader;
    for (final snake in simulation.snakes.where((snake) => snake.alive)) {
      if (!snake.segments.any(
        (segment) => visibleBounds.contains(Offset(segment.x, segment.y)),
      )) {
        continue;
      }
      _drawSnake(canvas, snake, isLeader: identical(snake, leader));
    }
    canvas.restore();
    _drawHud(canvas);
  }

  void _drawArena(Canvas canvas) {
    final arena = Rect.fromLTWH(
      0,
      0,
      simulation.config.arenaWidth,
      simulation.config.arenaHeight,
    );
    canvas.drawRect(arena, Paint()..color = const Color(0xFF102737));
    final grid = Paint()
      ..color = const Color(0x1829C8E8)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= arena.width; x += 120) {
      canvas.drawLine(Offset(x, 0), Offset(x, arena.height), grid);
    }
    for (var y = 0.0; y <= arena.height; y += 120) {
      canvas.drawLine(Offset(0, y), Offset(arena.width, y), grid);
    }

    final edgeDistance = min(
      min(simulation.player.head.x, arena.width - simulation.player.head.x),
      min(simulation.player.head.y, arena.height - simulation.player.head.y),
    );
    final danger = (1 - edgeDistance / 180).clamp(0.0, 1.0);
    canvas.drawRect(
      arena,
      Paint()
        ..color = Color.lerp(
          const Color(0xFF2FCBEF),
          const Color(0xFFFF5B4A),
          danger,
        )!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10 + danger * 8,
    );
  }

  void _drawFood(Canvas canvas, Rect visibleBounds) {
    for (final food in simulation.food) {
      if (!visibleBounds.contains(Offset(food.position.x, food.position.y))) {
        continue;
      }
      final radius = food.tier.radius;
      final pulse =
          1 +
          sin(simulation.survivalTime * 3.5 + food.id * 1.7) *
              (food.tier == SlitherFoodTier.large ? 1.4 : .7);
      final color = _foodColors[food.colorIndex % _foodColors.length];
      canvas.drawCircle(
        Offset(food.position.x, food.position.y),
        radius + 4 + pulse,
        Paint()..color = color.withAlpha(58),
      );
      final center = Offset(food.position.x, food.position.y);
      _drawFoodShape(canvas, center, radius + pulse * .18, food.tier, color);
      canvas.drawCircle(
        Offset(food.position.x - radius * .28, food.position.y - radius * .28),
        max(1.5, radius * .25),
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }
  }

  void _drawSnake(Canvas canvas, SlitherSnake snake, {required bool isLeader}) {
    final radius = simulation.radiusFor(snake);
    final color = snake.isPlayer
        ? const Color(0xFF5EF2BA)
        : _opponentColors[(snake.id - 1) % _opponentColors.length];
    final body = Paint()
      ..color = color
      ..strokeWidth = radius * 1.65
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final points = snake.segments.reversed
        .map((point) => Offset(point.x, point.y))
        .toList();
    if (points.length > 1) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var index = 1; index < points.length - 1; index++) {
        final point = points[index];
        final next = points[index + 1];
        final midpoint = Offset(
          (point.dx + next.dx) / 2,
          (point.dy + next.dy) / 2,
        );
        path.quadraticBezierTo(point.dx, point.dy, midpoint.dx, midpoint.dy);
      }
      path.lineTo(points.last.dx, points.last.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xB3071521)
          ..strokeWidth = radius * 2.05
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
      canvas.drawPath(path, body..strokeJoin = StrokeJoin.round);
      final pattern = Paint()..color = const Color(0x55FFFFFF);
      for (var index = 5; index < snake.segments.length; index += 9) {
        final point = snake.segments[index];
        canvas.drawCircle(
          Offset(point.x, point.y),
          max(1.5, radius * .24),
          pattern,
        );
      }
    }
    final head = Offset(snake.head.x, snake.head.y);
    canvas.drawCircle(head, radius * 1.08, Paint()..color = color);
    final facing = Offset(cos(snake.heading), sin(snake.heading));
    final side = Offset(-facing.dy, facing.dx);
    for (final direction in [-1.0, 1.0]) {
      final eye =
          head + facing * (radius * .42) + side * (radius * .34) * direction;
      canvas.drawCircle(
        eye,
        max(2.2, radius * .22),
        Paint()..color = const Color(0xFFFFFFFF),
      );
      canvas.drawCircle(
        eye + facing * max(.9, radius * .09),
        max(1, radius * .1),
        Paint()..color = const Color(0xFF071521),
      );
    }
    final mouthCenter = head + facing * (radius * .62);
    canvas.drawArc(
      Rect.fromCenter(
        center: mouthCenter,
        width: radius * .5,
        height: radius * .38,
      ),
      .15,
      pi - .3,
      false,
      Paint()
        ..color = const Color(0xFF173344)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, radius * .1)
        ..strokeCap = StrokeCap.round,
    );
    if (isLeader) {
      _drawCrown(canvas, head - Offset(0, radius * 1.9), radius);
    }
    if (snake.age < simulation.config.spawnProtection) {
      canvas.drawCircle(
        head,
        radius + 9,
        Paint()
          ..color = const Color(0xAAFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  void _drawHud(Canvas canvas) {
    _drawLeaderboard(canvas);
    _drawMinimap(canvas);
    _drawEdgeGuidance(canvas);
    if (simulation.player.age < simulation.config.spawnProtection) {
      _drawText(
        canvas,
        'SPAWN SHIELD',
        Offset(size.x / 2, size.y - 34),
        const Color(0xFFFFFFFF),
        14,
        centered: true,
      );
    }
    if (simulation.isGameOver) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.x, size.y),
        Paint()..color = const Color(0x99000000),
      );
      _drawText(
        canvas,
        simulation.gameOverReason == SlitherGameOverReason.wall
            ? 'WALL HIT'
            : 'SNAKE HIT',
        Offset(size.x / 2, size.y / 2 - 16),
        const Color(0xFFFF7568),
        32,
        centered: true,
      );
      _drawText(
        canvas,
        'SCORE ${simulation.score}  •  ${simulation.survivalTime.floor()}s',
        Offset(size.x / 2, size.y / 2 + 26),
        const Color(0xFFFFFFFF),
        16,
        centered: true,
      );
    }
  }

  void _drawFoodShape(
    Canvas canvas,
    Offset center,
    double radius,
    SlitherFoodTier tier,
    Color color,
  ) {
    if (tier == SlitherFoodTier.small) {
      canvas.drawCircle(center, radius, Paint()..color = color);
      return;
    }
    final points = tier == SlitherFoodTier.medium ? 6 : 10;
    final path = Path();
    for (var index = 0; index < points; index++) {
      final angle = -pi / 2 + index * 2 * pi / points;
      final pointRadius = tier == SlitherFoodTier.large && index.isOdd
          ? radius * .64
          : radius;
      final point =
          center + Offset(cos(angle) * pointRadius, sin(angle) * pointRadius);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawMinimap(Canvas canvas) {
    final map = minimapRect;
    canvas.drawRRect(
      RRect.fromRectAndRadius(map, const Radius.circular(10)),
      Paint()..color = const Color(0xD10A1925),
    );
    final inner = map.deflate(6);
    canvas.drawRect(
      inner,
      Paint()
        ..color = const Color(0xFF2FCBEF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    Offset project(SlitherPoint point) => Offset(
      inner.left + point.x / simulation.config.arenaWidth * inner.width,
      inner.top + point.y / simulation.config.arenaHeight * inner.height,
    );

    for (final snake in simulation.snakes.where((snake) => snake.alive)) {
      canvas.drawCircle(
        project(snake.head),
        snake.isPlayer ? 2.8 : 1.5,
        Paint()
          ..color = snake.isPlayer
              ? const Color(0xFF5EF2BA)
              : const Color(0xFFFF8A65),
      );
    }
    final visible = visibleWorldBounds;
    final viewport = Rect.fromLTRB(
      inner.left + visible.left / simulation.config.arenaWidth * inner.width,
      inner.top + visible.top / simulation.config.arenaHeight * inner.height,
      inner.left + visible.right / simulation.config.arenaWidth * inner.width,
      inner.top + visible.bottom / simulation.config.arenaHeight * inner.height,
    ).intersect(inner);
    canvas.drawRect(
      viewport,
      Paint()
        ..color = const Color(0x99FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawEdgeGuidance(Canvas canvas) {
    final paint = Paint()..color = const Color(0xFFFFD54F);
    for (final edge in nearbyArenaEdges) {
      final center = switch (edge) {
        SlitherArenaEdge.left => Offset(18, size.y / 2),
        SlitherArenaEdge.top => Offset(size.x / 2, 102),
        SlitherArenaEdge.right => Offset(size.x - 18, size.y / 2),
        SlitherArenaEdge.bottom => Offset(size.x / 2, size.y - 48),
      };
      final angle = switch (edge) {
        SlitherArenaEdge.left => 0.0,
        SlitherArenaEdge.top => pi / 2,
        SlitherArenaEdge.right => pi,
        SlitherArenaEdge.bottom => -pi / 2,
      };
      final forward = Offset(cos(angle), sin(angle));
      final side = Offset(-forward.dy, forward.dx);
      final path = Path()
        ..moveTo(center.dx + forward.dx * 11, center.dy + forward.dy * 11)
        ..lineTo(
          center.dx - forward.dx * 7 + side.dx * 7,
          center.dy - forward.dy * 7 + side.dy * 7,
        )
        ..lineTo(
          center.dx - forward.dx * 7 - side.dx * 7,
          center.dy - forward.dy * 7 - side.dy * 7,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  void _drawLeaderboard(Canvas canvas) {
    final width = min(106.0, size.x * .34);
    final ranked = simulation.leaderboard.take(10).toList();
    final height = 23.0 + ranked.length * 11;
    final left = size.x - width - 8;
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, 8, width, height),
      const Radius.circular(11),
    );
    canvas.drawRRect(panel, Paint()..color = const Color(0x660A1925));
    _drawText(
      canvas,
      'TOP 10',
      Offset(left + 7, 14),
      const Color(0xFFFFD54F),
      8,
    );
    for (var index = 0; index < ranked.length; index++) {
      final snake = ranked[index];
      final name = snake.isPlayer ? 'YOU' : 'SNAKE ${snake.id}';
      final color = snake.isPlayer
          ? const Color(0xFF5EF2BA)
          : const Color(0xFFD7F5FF);
      _drawText(
        canvas,
        '${index + 1}. $name',
        Offset(left + 7, 28 + index * 11),
        color,
        7,
      );
      final score = snake.score.toString();
      final painter = _textPainter(score, color, 7);
      painter.paint(
        canvas,
        Offset(left + width - painter.width - 7, 28 + index * 11),
      );
    }
  }

  void _drawCrown(Canvas canvas, Offset center, double radius) {
    final width = max(13.0, radius * 1.25);
    final height = max(9.0, radius * .8);
    final path = Path()
      ..moveTo(center.dx - width / 2, center.dy + height / 2)
      ..lineTo(center.dx - width / 2, center.dy - height / 3)
      ..lineTo(center.dx - width / 5, center.dy)
      ..lineTo(center.dx, center.dy - height / 2)
      ..lineTo(center.dx + width / 5, center.dy)
      ..lineTo(center.dx + width / 2, center.dy - height / 3)
      ..lineTo(center.dx + width / 2, center.dy + height / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFD54F));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF9F1C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double size, {
    bool centered = false,
  }) {
    final painter = _textPainter(text, color, size);
    painter.paint(
      canvas,
      centered
          ? offset - Offset(painter.width / 2, painter.height / 2)
          : offset,
    );
  }

  TextPainter _textPainter(String text, Color color, double size) =>
      TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: size,
            fontWeight: FontWeight.w800,
            fontFamily: 'Fredoka',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  static const _opponentColors = [
    Color(0xFFFF6B61),
    Color(0xFF47B8FF),
    Color(0xFFB779FF),
    Color(0xFFFF9E45),
    Color(0xFFFF5FA2),
    Color(0xFF85E36A),
  ];

  static const _foodColors = [
    Color(0xFFFFD54F),
    Color(0xFFFF6B8A),
    Color(0xFF61E7FF),
    Color(0xFFB887FF),
    Color(0xFF7BF178),
    Color(0xFFFF9F43),
  ];
}
