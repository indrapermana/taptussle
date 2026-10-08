import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'lane_dash_bot.dart';
import 'lane_dash_model.dart';

/// Flame adapter for Lane Dash simulation, rendering, and match reporting.
class LaneDashGame extends Game {
  LaneDashGame(this.session)
    : model = LaneDashModel(
        difficulty: session.options.botDifficulty ?? BotDifficulty.normal,
      ),
      bot = session.options.mode == PlayMode.bot
          ? LaneDashBot(session.options.botDifficulty!)
          : null;

  final MatchSession session;
  final LaneDashModel model;
  final LaneDashBot? bot;
  final _reportedProgress = [0, 0];
  final _reportedCollisions = [0, 0];
  final _visualLaneX = [180.0, 180.0];
  final _lastLane = [1, 1];
  final _laneChangeEffect = [0.0, 0.0];
  final Map<String, ui.Image> _sprites = {};
  var _reportedCountdown = 3;
  double _goEffect = 0;
  bool _stopped = false;

  static const _assetRoot = 'assets/games/lane_dash/';
  static const _assetNames = <String>[
    'car_blue',
    'car_red',
    'car_green',
    'car_yellow',
    'car_purple',
    'road_straight',
    'road_dashed',
    'road_edge_left',
    'road_edge_right',
    'ready_text',
    'go_text',
    'boost_trail_blue',
    'boost_trail_red',
    'drift_dust',
    'speed_streak',
  ];

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await Future.wait(
      _assetNames.map((name) async {
        final data = await rootBundle.load('$_assetRoot$name.png');
        _sprites[name] = await decodeImageFromList(data.buffer.asUint8List());
      }),
    );
  }

  void resetMatch() {
    model.reset();
    bot?.reset();
    _reportedProgress[0] = _reportedProgress[1] = 0;
    _reportedCollisions[0] = _reportedCollisions[1] = 0;
    _visualLaneX[0] = _visualLaneX[1] = 180;
    _lastLane[0] = _lastLane[1] = 1;
    _laneChangeEffect[0] = _laneChangeEffect[1] = 0;
    _reportedCountdown = 3;
    _goEffect = 0;
  }

  void stopMatch() {
    _stopped = true;
    pauseEngine();
  }

  void move(int player, int direction) => model.move(player, direction);

  String carSpriteForPlayer(int player) {
    if (player == 0) return 'car_blue';
    if (session.options.mode == PlayMode.friend) return 'car_red';
    return switch (session.options.botDifficulty ?? BotDifficulty.normal) {
      BotDifficulty.easy => 'car_green',
      BotDifficulty.normal => 'car_yellow',
      BotDifficulty.hard => 'car_purple',
    };
  }

  @override
  Color backgroundColor() => const Color(0xFF142333);

  @override
  void update(double dt) {
    if (_stopped || session.phase != MatchPhase.playing) return;
    _goEffect = math.max(0, _goEffect - dt);
    bot?.update(model, dt);
    model.update(dt);
    for (var player = 0; player < 2; player++) {
      if (_lastLane[player] != model.lanes[player]) {
        _lastLane[player] = model.lanes[player];
        _laneChangeEffect[player] = .28;
      } else {
        _laneChangeEffect[player] = math.max(0, _laneChangeEffect[player] - dt);
      }
      final target = 60.0 + 120.0 * model.lanes[player];
      final blend = 1 - math.exp(-dt * 15);
      _visualLaneX[player] += (target - _visualLaneX[player]) * blend;
    }
    final countdown = model.countdown.ceil();
    if (countdown != _reportedCountdown) {
      _reportedCountdown = countdown;
      if (countdown == 0) _goEffect = .7;
      SoundEffects.play(
        countdown == 0 ? SoundEffect.countdownGo : SoundEffect.countdownTick,
      );
    }
    if (model.collisionCount[0] != _reportedCollisions[0] ||
        model.collisionCount[1] != _reportedCollisions[1]) {
      _reportedCollisions[0] = model.collisionCount[0];
      _reportedCollisions[1] = model.collisionCount[1];
      SoundEffects.play(SoundEffect.impactHeavy);
    }
    final progress = [model.distance[0].round(), model.distance[1].round()];
    final result = model.result;
    if (result == LaneDashResult.draw || result == LaneDashResult.timeout) {
      session.reportNonPointResult(
        winner: null,
        scores: progress,
        details: result == LaneDashResult.draw
            ? 'Both runners reached ${LaneDashModel.finishDistance.round()} m together.'
            : 'The race ended level at ${model.distance[0].round()} m.',
      );
    } else if (result == LaneDashResult.playerOne ||
        result == LaneDashResult.playerTwo) {
      final winner = result == LaneDashResult.playerOne ? 0 : 1;
      final loser = 1 - winner;
      session.reportNonPointResult(
        winner: winner,
        scores: progress,
        details:
            '${session.options.playerLabel(winner)} reached '
            '${model.distance[winner].round()} m first; '
            '${session.options.playerLabel(loser)} reached '
            '${model.distance[loser].round()} m.',
      );
    } else if (progress[0] != _reportedProgress[0] ||
        progress[1] != _reportedProgress[1]) {
      _reportedProgress[0] = progress[0];
      _reportedProgress[1] = progress[1];
      session.reportScore(progress[0], progress[1]);
    }
  }

  @override
  void render(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0) return;
    canvas.save();
    canvas.scale(size.x / 360, size.y / 600);
    final divider = Paint()
      ..color = const Color(0xFFFFD166)
      ..strokeWidth = 3;
    for (final top in [true, false]) {
      final panelTop = top ? 0.0 : 300.0;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, panelTop, 360, 300));
      final player = top ? 1 : 0;
      _drawRoad(canvas, player: player, top: top, panelTop: panelTop);
      final runnerY = top ? 66.0 : 534.0;
      for (final obstacle in model.obstaclesFor(player)) {
        final gap = obstacle.distance - model.distance[player];
        if (gap < -5 || gap > 650) continue;
        final y = top ? runnerY + gap * 1.15 : runnerY - gap * 1.15;
        for (final lane in obstacle.blockedLanes) {
          _drawCone(canvas, 60 + 120.0 * lane, y);
        }
      }
      final color = player == 0
          ? const Color(0xFF29C9FF)
          : session.options.mode == PlayMode.friend
          ? const Color(0xFFFF7043)
          : const Color(0xFFFFD166);
      final runnerX = _visualLaneX[player];
      _drawRunner(
        canvas,
        player: player,
        center: Offset(runnerX, runnerY),
        top: top,
        color: color,
      );
      final hudY = top ? 16.0 : 322.0;
      final participant = session.options.playerLabel(player).toUpperCase();
      final distance =
          '${model.distance[player].round()} / ${LaneDashModel.finishDistance.round()} m';
      if (top) {
        _drawLabel(
          canvas,
          participant,
          const Offset(62, 17),
          color,
          12,
          centered: true,
          rotation: math.pi,
        );
        _drawLabel(
          canvas,
          distance,
          const Offset(274, 17),
          const Color(0xFFFFFFFF),
          12,
          centered: true,
          rotation: math.pi,
        );
      } else {
        _drawLabel(canvas, participant, Offset(12, hudY), color, 12);
        _drawLabel(
          canvas,
          distance,
          Offset(348, hudY),
          const Color(0xFFFFFFFF),
          12,
          right: true,
        );
      }
      final bar = Rect.fromLTWH(12, top ? 281 : 305, 336, 5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(3)),
        Paint()..color = const Color(0x3DFFFFFF),
      );
      final progress = Rect.fromLTWH(
        bar.left,
        bar.top,
        bar.width *
            (model.distance[player] / LaneDashModel.finishDistance).clamp(
              0.0,
              1.0,
            ),
        bar.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(progress, const Radius.circular(3)),
        Paint()..color = color,
      );
      if (model.slowdown[player] > 0) {
        _drawLabel(
          canvas,
          'HIT • SLOW',
          Offset(180, top ? 258 : 342),
          const Color(0xFFFFC36B),
          13,
          centered: true,
          rotation: top ? math.pi : 0,
        );
      }
      if (top) {
        _drawLabel(
          canvas,
          'HITS ${model.collisionCount[player]}',
          const Offset(304, 284),
          const Color(0xB3FFFFFF),
          10,
          centered: true,
          rotation: math.pi,
        );
      } else {
        _drawLabel(
          canvas,
          'HITS ${model.collisionCount[player]}',
          const Offset(12, 322),
          const Color(0xB3FFFFFF),
          10,
        );
      }
      canvas.restore();
    }
    canvas.drawLine(const Offset(0, 300), const Offset(360, 300), divider);
    if (model.countdown > 0) {
      _drawSprite(
        canvas,
        'ready_text',
        const Offset(180, 220),
        const Size(142, 80),
        rotation: math.pi,
        opacity: .88,
      );
      _drawSprite(
        canvas,
        'ready_text',
        const Offset(180, 380),
        const Size(142, 80),
        opacity: .88,
      );
      _drawLabel(
        canvas,
        model.countdown.ceil().toString(),
        const Offset(180, 269),
        const Color(0xFFFFFFFF),
        34,
        centered: true,
        rotation: math.pi,
      );
      _drawLabel(
        canvas,
        model.countdown.ceil().toString(),
        const Offset(180, 331),
        const Color(0xFFFFFFFF),
        34,
        centered: true,
      );
    } else if (_goEffect > 0) {
      _drawSprite(
        canvas,
        'go_text',
        const Offset(180, 235),
        Size(142 + 18 * _goEffect, 80 + 12 * _goEffect),
        rotation: math.pi,
        opacity: (_goEffect / .3).clamp(0, 1).toDouble(),
      );
      _drawSprite(
        canvas,
        'go_text',
        const Offset(180, 365),
        Size(142 + 18 * _goEffect, 80 + 12 * _goEffect),
        opacity: (_goEffect / .3).clamp(0, 1).toDouble(),
      );
    }
    canvas.restore();
  }

  void _drawRoad(
    Canvas canvas, {
    required int player,
    required bool top,
    required double panelTop,
  }) {
    canvas.drawRect(
      Rect.fromLTWH(0, panelTop, 360, 300),
      Paint()..color = const Color(0xFF101B28),
    );
    const tileHeight = 240.0;
    final offset = (model.distance[player] * 2.2) % tileHeight;
    for (var tile = -1; tile <= 2; tile++) {
      final y = top
          ? panelTop + tile * tileHeight - offset
          : panelTop + tile * tileHeight + offset;
      final laneSprites = [
        'road_edge_left',
        tile.isEven ? 'road_dashed' : 'road_straight',
        'road_edge_right',
      ];
      for (var lane = 0; lane < 3; lane++) {
        _drawSpriteRect(
          canvas,
          laneSprites[lane],
          Rect.fromLTWH(lane * 120.0, y, 120, tileHeight + 1),
          opacity: .92,
        );
      }
    }
    canvas.drawRect(
      Rect.fromLTWH(0, panelTop, 360, 300),
      Paint()
        ..shader = LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: const [Color(0x8A07111F), Color(0x0007111F)],
        ).createShader(Rect.fromLTWH(0, panelTop, 360, 300)),
    );
  }

  void _drawRunner(
    Canvas canvas, {
    required int player,
    required Offset center,
    required bool top,
    required Color color,
  }) {
    final rotation = top ? 0.0 : math.pi;
    final direction = top ? -1.0 : 1.0;
    if (model.countdown <= 0) {
      _drawSprite(
        canvas,
        'speed_streak',
        center + Offset(0, 32 * direction),
        const Size(76, 92),
        rotation: rotation,
        opacity: model.slowdown[player] > 0 ? .12 : .28,
      );
      final trail = player == 0
          ? 'boost_trail_blue'
          : session.options.mode == PlayMode.friend
          ? 'boost_trail_red'
          : 'speed_streak';
      _drawSprite(
        canvas,
        trail,
        center + Offset(0, 25 * direction),
        const Size(55, 72),
        rotation: rotation,
        opacity: model.slowdown[player] > 0 ? .12 : .42,
      );
    }
    if (_laneChangeEffect[player] > 0) {
      _drawSprite(
        canvas,
        'drift_dust',
        center + Offset(0, 24 * direction),
        const Size(67, 54),
        rotation: rotation,
        opacity: (_laneChangeEffect[player] / .28).clamp(0, 1).toDouble(),
      );
    }
    if (_sprites[carSpriteForPlayer(player)] == null) {
      canvas.drawCircle(center, 20, Paint()..color = color);
      return;
    }
    _drawSprite(
      canvas,
      carSpriteForPlayer(player),
      center,
      const Size(52, 76),
      rotation: rotation,
    );
  }

  void _drawSprite(
    Canvas canvas,
    String name,
    Offset center,
    Size drawSize, {
    double rotation = 0,
    double opacity = 1,
  }) {
    final image = _sprites[name];
    if (image == null) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotation != 0) canvas.rotate(rotation);
    _drawSpriteRect(
      canvas,
      name,
      Rect.fromCenter(
        center: Offset.zero,
        width: drawSize.width,
        height: drawSize.height,
      ),
      opacity: opacity,
    );
    canvas.restore();
  }

  void _drawSpriteRect(
    Canvas canvas,
    String name,
    Rect target, {
    double opacity = 1,
  }) {
    final image = _sprites[name];
    if (image == null) return;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      target,
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );
  }

  void _drawCone(Canvas canvas, double x, double y) {
    final path = Path()
      ..moveTo(x, y - 13)
      ..lineTo(x + 10, y + 11)
      ..lineTo(x - 10, y + 11)
      ..close();
    canvas.drawShadow(path, const Color(0x8A000000), 3, true);
    canvas.drawPath(path, Paint()..color = const Color(0xFFFF8B45));
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFD9BB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(x - 5, y + 3),
      Offset(x + 5, y + 3),
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y + 12), width: 25, height: 4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFFF8B45),
    );
  }

  void _drawLabel(
    Canvas canvas,
    String label,
    Offset point,
    Color color,
    double fontSize, {
    bool centered = false,
    bool right = false,
    double rotation = 0,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: .5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final x = centered
        ? -painter.width / 2
        : right
        ? -painter.width
        : 0.0;
    canvas.save();
    canvas.translate(point.dx, point.dy);
    if (rotation != 0) canvas.rotate(rotation);
    painter.paint(canvas, Offset(x, -painter.height / 2));
    canvas.restore();
    painter.dispose();
  }
}
