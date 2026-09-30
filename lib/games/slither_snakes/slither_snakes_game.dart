import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../core/haptic_service.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'slither_simulation.dart';

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

  void reset({int round = 0}) {
    simulation = SlitherSimulation(seed: seed + round, config: config);
    cameraCenter = simulation.player.head;
    _resultReported = false;
    _reportedPlayerFood = 0;
    _reportedAliveOpponents = config.aiCount;
  }

  void stopMatch() {
    _stopped = true;
    simulation.steerToward(null);
    pauseEngine();
  }

  void clearSteering() => simulation.steerToward(null);

  void steerFromScreen(Offset screenPosition) {
    if (_stopped || session.phase != MatchPhase.playing) return;
    simulation.steerToward(screenToWorld(screenPosition));
  }

  SlitherPoint screenToWorld(Offset screenPosition) => SlitherPoint(
    screenPosition.dx - size.x / 2 + cameraCenter.x,
    screenPosition.dy - size.y / 2 + cameraCenter.y,
  );

  Offset worldToScreen(SlitherPoint worldPosition) => Offset(
    worldPosition.x - cameraCenter.x + size.x / 2,
    worldPosition.y - cameraCenter.y + size.y / 2,
  );

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
    final halfWidth = size.x / 2;
    final halfHeight = size.y / 2;
    final arenaWidth = simulation.config.arenaWidth;
    final arenaHeight = simulation.config.arenaHeight;
    cameraCenter = SlitherPoint(
      arenaWidth <= size.x
          ? arenaWidth / 2
          : simulation.player.head.x.clamp(halfWidth, arenaWidth - halfWidth),
      arenaHeight <= size.y
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
    canvas.translate(size.x / 2 - cameraCenter.x, size.y / 2 - cameraCenter.y);
    _drawArena(canvas);
    _drawFood(canvas);
    for (final snake in simulation.snakes.where((snake) => snake.alive)) {
      _drawSnake(canvas, snake);
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

  void _drawFood(Canvas canvas) {
    for (final food in simulation.food) {
      canvas.drawCircle(
        Offset(food.position.x, food.position.y),
        simulation.config.foodRadius + 5,
        Paint()..color = const Color(0x4435D7FF),
      );
      canvas.drawCircle(
        Offset(food.position.x, food.position.y),
        simulation.config.foodRadius,
        Paint()..color = const Color(0xFFFFD54F),
      );
      canvas.drawCircle(
        Offset(food.position.x - 2, food.position.y - 2),
        2.5,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }
  }

  void _drawSnake(Canvas canvas, SlitherSnake snake) {
    final color = snake.isPlayer
        ? const Color(0xFF5EF2BA)
        : _opponentColors[(snake.id - 1) % _opponentColors.length];
    final body = Paint()
      ..color = color
      ..strokeWidth = simulation.config.snakeRadius * 1.65
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final points = snake.segments.reversed
        .map((point) => Offset(point.x, point.y))
        .toList();
    if (points.length > 1) canvas.drawPoints(PointMode.polygon, points, body);
    final head = Offset(snake.head.x, snake.head.y);
    canvas.drawCircle(
      head,
      simulation.config.snakeRadius * 1.08,
      Paint()..color = color,
    );
    final facing = Offset(cos(snake.heading), sin(snake.heading));
    final side = Offset(-facing.dy, facing.dx);
    for (final direction in [-1.0, 1.0]) {
      final eye = head + facing * 5 + side * 4 * direction;
      canvas.drawCircle(eye, 2.7, Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawCircle(
        eye + facing * 1.1,
        1.2,
        Paint()..color = const Color(0xFF071521),
      );
    }
    if (snake.age < simulation.config.spawnProtection) {
      canvas.drawCircle(
        head,
        simulation.config.snakeRadius + 9,
        Paint()
          ..color = const Color(0xAAFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  void _drawHud(Canvas canvas) {
    final panel = RRect.fromRectAndRadius(
      const Rect.fromLTWH(12, 12, 190, 64),
      const Radius.circular(16),
    );
    canvas.drawRRect(panel, Paint()..color = const Color(0xC90A1925));
    _drawText(
      canvas,
      'SCORE ${simulation.score}',
      const Offset(24, 20),
      const Color(0xFFFFD54F),
      19,
    );
    _drawText(
      canvas,
      'TIME ${simulation.survivalTime.floor()}s  •  SPEED ${simulation.speedFor(simulation.player).round()}',
      const Offset(24, 48),
      const Color(0xFFD7F5FF),
      11,
    );
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

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double size, {
    bool centered = false,
  }) {
    final painter = TextPainter(
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
    painter.paint(
      canvas,
      centered
          ? offset - Offset(painter.width / 2, painter.height / 2)
          : offset,
    );
  }

  static const _opponentColors = [
    Color(0xFFFF6B61),
    Color(0xFF47B8FF),
    Color(0xFFB779FF),
    Color(0xFFFF9E45),
    Color(0xFFFF5FA2),
    Color(0xFF85E36A),
  ];
}
