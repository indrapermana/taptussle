import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../../core/haptic_service.dart';
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
  final _laneChangeDirection = [0, 0];
  final _collisionEffect = [0.0, 0.0];
  final Map<String, ui.Image> _sprites = {};
  final ValueNotifier<String> accessibilityAnnouncement = ValueNotifier(
    'Get ready',
  );
  var _reportedCountdown = 3;
  double _goEffect = 0;
  LaneDashResult? _pendingResult;
  double _finishPresentationRemaining = 0;
  bool _stopped = false;

  static const finishPresentationDuration = 1.25;

  static const _assetRoot = 'assets/games/lane_dash/';
  static const _assetNames = <String>[
    'car_blue',
    'car_red',
    'car_green',
    'car_yellow',
    'car_purple',
    'road_straight',
    'road_edge_left',
    'road_edge_right',
    'boost_trail_blue',
    'boost_trail_red',
    'drift_dust',
    'speed_streak',
    'obstacle_cone',
    'obstacle_box',
    'obstacle_barrier',
    'obstacle_barricade',
    'obstacle_rock',
    'obstacle_tires',
    'obstacle_car',
    'obstacle_van',
    'obstacle_truck',
    'hit_spark',
    'hit_debris',
    'hit_smoke',
    'hit_ring',
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
    _laneChangeDirection[0] = _laneChangeDirection[1] = 0;
    _collisionEffect[0] = _collisionEffect[1] = 0;
    _reportedCountdown = 3;
    _goEffect = 0;
    _pendingResult = null;
    _finishPresentationRemaining = 0;
    accessibilityAnnouncement.value = 'Get ready';
  }

  void stopMatch() {
    _stopped = true;
    pauseEngine();
  }

  void move(int player, int direction) => model.move(player, direction);

  bool get isPresentingFinish => _pendingResult != null;

  String carSpriteForPlayer(int player) {
    if (player == 0) return 'car_blue';
    if (session.options.mode == PlayMode.friend) return 'car_red';
    return switch (session.options.botDifficulty ?? BotDifficulty.normal) {
      BotDifficulty.easy => 'car_green',
      BotDifficulty.normal => 'car_yellow',
      BotDifficulty.hard => 'car_purple',
    };
  }

  String obstacleSpriteForKind(LaneObstacleKind kind) => switch (kind) {
    LaneObstacleKind.cone => 'obstacle_cone',
    LaneObstacleKind.box => 'obstacle_box',
    LaneObstacleKind.barrier => 'obstacle_barrier',
    LaneObstacleKind.barricade => 'obstacle_barricade',
    LaneObstacleKind.rock => 'obstacle_rock',
    LaneObstacleKind.tires => 'obstacle_tires',
    LaneObstacleKind.car => 'obstacle_car',
    LaneObstacleKind.van => 'obstacle_van',
    LaneObstacleKind.truck => 'obstacle_truck',
  };

  @override
  Color backgroundColor() => const Color(0xFF142333);

  @override
  void update(double dt) {
    if (_stopped || session.phase != MatchPhase.playing) return;
    _goEffect = math.max(0, _goEffect - dt);
    for (var player = 0; player < 2; player++) {
      _collisionEffect[player] = math.max(0, _collisionEffect[player] - dt);
    }
    bot?.update(model, dt);
    model.update(dt);
    for (var player = 0; player < 2; player++) {
      if (_lastLane[player] != model.lanes[player]) {
        _laneChangeDirection[player] =
            (model.lanes[player] - _lastLane[player]).sign;
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
      accessibilityAnnouncement.value = countdown == 0 ? 'Go' : '$countdown';
      SoundEffects.play(
        countdown == 0 ? SoundEffect.countdownGo : SoundEffect.countdownTick,
      );
    }
    var collided = false;
    final collidedPlayers = <String>[];
    for (var player = 0; player < 2; player++) {
      if (model.collisionCount[player] != _reportedCollisions[player]) {
        _reportedCollisions[player] = model.collisionCount[player];
        _collisionEffect[player] = .48;
        collided = true;
        collidedPlayers.add(session.options.playerLabel(player));
      }
    }
    if (collided) {
      SoundEffects.play(SoundEffect.impactHeavy);
      HapticEffects.paddleHit();
      accessibilityAnnouncement.value =
          '${collidedPlayers.join(' and ')} hit an obstacle and slowed down';
    }
    final progress = [model.distance[0].round(), model.distance[1].round()];
    final result = model.result;
    if (result != null) {
      if (_pendingResult == null) {
        _pendingResult = result;
        _finishPresentationRemaining = finishPresentationDuration;
        SoundEffects.play(SoundEffect.roundReveal);
        accessibilityAnnouncement.value = switch (result) {
          LaneDashResult.playerOne =>
            '${session.options.playerLabel(0)} wins the race',
          LaneDashResult.playerTwo =>
            '${session.options.playerLabel(1)} wins the race',
          LaneDashResult.draw ||
          LaneDashResult.timeout => 'Photo finish. The race is a draw',
        };
      } else {
        _finishPresentationRemaining = math.max(
          0,
          _finishPresentationRemaining - dt,
        );
      }
      if (_finishPresentationRemaining <= 0) {
        _reportResult(result, progress);
      }
    } else if (progress[0] != _reportedProgress[0] ||
        progress[1] != _reportedProgress[1]) {
      _reportedProgress[0] = progress[0];
      _reportedProgress[1] = progress[1];
      session.reportScore(progress[0], progress[1]);
    }
  }

  void _reportResult(LaneDashResult result, List<int> progress) {
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
      if (_collisionEffect[player] > 0) {
        final strength = _collisionEffect[player] / .48;
        canvas.translate(
          math.sin(_collisionEffect[player] * 95) * 3 * strength,
          math.cos(_collisionEffect[player] * 73) * 1.5 * strength,
        );
      }
      _drawRoad(canvas, player: player, top: top, panelTop: panelTop);
      final runnerY = top ? 66.0 : 534.0;
      for (final obstacle in model.obstaclesFor(player)) {
        final gap = model.obstacleGap(player, obstacle);
        if (gap < -80 || gap > 650) continue;
        final y = top ? runnerY + gap * 1.15 : runnerY - gap * 1.15;
        for (final lane in obstacle.blockedLanes) {
          _drawObstacle(
            canvas,
            obstacle.kind,
            Offset(60 + 120.0 * lane, y),
            top: top,
          );
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
      _drawSwipeFeedback(
        canvas,
        player: player,
        center: Offset(runnerX, runnerY),
        color: color,
      );
      _drawCollisionFeedback(
        canvas,
        player: player,
        center: Offset(runnerX, runnerY),
        top: top,
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
      final bar = Rect.fromLTWH(12, top ? 279 : 305, 336, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(5)),
        Paint()..color = const Color(0x66101B28),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(5)),
        Paint()
          ..color = const Color(0x80FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      final progressRatio =
          (model.distance[player] / LaneDashModel.finishDistance).clamp(
            0.0,
            1.0,
          );
      final progress = Rect.fromLTWH(
        bar.left,
        bar.top,
        bar.width * progressRatio,
        bar.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(progress, const Radius.circular(5)),
        Paint()..color = color,
      );
      canvas.drawCircle(
        Offset(bar.left + bar.width * progressRatio, bar.center.dy),
        5,
        Paint()..color = const Color(0xFFFFFFFF),
      );
      if (model.slowdown[player] > 0) {
        _drawSlowdownBadge(canvas, player: player, top: top);
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
    if (_pendingResult != null) {
      _drawFinishPresentation(canvas, _pendingResult!);
    } else if (model.countdown > 0) {
      _drawCountdownBanner(
        canvas,
        label: 'READY',
        detail: model.countdown.ceil().toString(),
      );
    } else if (_goEffect > 0) {
      _drawCountdownBanner(
        canvas,
        label: 'GO!',
        opacity: (_goEffect / .3).clamp(0, 1).toDouble(),
      );
    }
    canvas.restore();
  }

  void _drawCountdownBanner(
    Canvas canvas, {
    required String label,
    String? detail,
    double opacity = 1,
  }) {
    final accent = label == 'GO!'
        ? const Color(0xFFFFD166)
        : const Color(0xFFEEF7FF);
    for (final top in [true, false]) {
      final center = Offset(180, top ? 247 : 353);
      final plate = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center,
          width: detail == null ? 128 : 150,
          height: detail == null ? 58 : 76,
        ),
        const Radius.circular(18),
      );
      canvas.drawRRect(
        plate,
        Paint()
          ..color = const Color(0xE6122030).withValues(alpha: .9 * opacity),
      );
      canvas.drawRRect(
        plate,
        Paint()
          ..color = accent.withValues(alpha: .9 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final rotation = top ? math.pi : 0.0;
      _drawLabel(
        canvas,
        label,
        center + Offset(0, detail == null ? 0 : (top ? 14 : -14)),
        accent.withValues(alpha: opacity),
        detail == null ? 34 : 23,
        centered: true,
        rotation: rotation,
      );
      if (detail != null) {
        _drawLabel(
          canvas,
          detail,
          center + Offset(0, top ? -17 : 17),
          const Color(0xFFFFFFFF).withValues(alpha: opacity),
          26,
          centered: true,
          rotation: rotation,
        );
      }
    }
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
        'road_straight',
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
    final rotation = top ? math.pi : 0.0;
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

  void _drawSwipeFeedback(
    Canvas canvas, {
    required int player,
    required Offset center,
    required Color color,
  }) {
    if (_laneChangeEffect[player] <= 0 || _laneChangeDirection[player] == 0) {
      return;
    }
    final direction = _laneChangeDirection[player].toDouble();
    final opacity = (_laneChangeEffect[player] / .28).clamp(0, 1).toDouble();
    final arrowCenter = center + Offset(42 * direction, 0);
    final path = Path()
      ..moveTo(arrowCenter.dx + 9 * direction, arrowCenter.dy)
      ..lineTo(arrowCenter.dx - 5 * direction, arrowCenter.dy - 10)
      ..moveTo(arrowCenter.dx + 9 * direction, arrowCenter.dy)
      ..lineTo(arrowCenter.dx - 5 * direction, arrowCenter.dy + 10);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawCollisionFeedback(
    Canvas canvas, {
    required int player,
    required Offset center,
    required bool top,
  }) {
    final effect = _collisionEffect[player];
    if (effect > 0) {
      final opacity = (effect / .48).clamp(0, 1).toDouble();
      final rotation = top ? math.pi : 0.0;
      _drawSprite(
        canvas,
        'hit_ring',
        center,
        const Size(96, 88),
        rotation: rotation,
        opacity: opacity * .75,
      );
      _drawSprite(
        canvas,
        'hit_spark',
        center,
        const Size(67, 67),
        rotation: rotation,
        opacity: opacity,
      );
      _drawSprite(
        canvas,
        'hit_debris',
        center,
        const Size(92, 78),
        rotation: rotation,
        opacity: opacity,
      );
    }
    if (model.slowdown[player] > 0) {
      final direction = top ? -1.0 : 1.0;
      _drawSprite(
        canvas,
        'hit_smoke',
        center + Offset(0, 27 * direction),
        const Size(58, 49),
        rotation: top ? math.pi : 0,
        opacity: (model.slowdown[player] / .9).clamp(.18, .62).toDouble(),
      );
    }
  }

  void _drawSlowdownBadge(
    Canvas canvas, {
    required int player,
    required bool top,
  }) {
    final center = Offset(180, top ? 254 : 346);
    final badge = Rect.fromCenter(center: center, width: 118, height: 27);
    canvas.drawRRect(
      RRect.fromRectAndRadius(badge, const Radius.circular(14)),
      Paint()..color = const Color(0xE6291720),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badge, const Radius.circular(14)),
      Paint()
        ..color = const Color(0xFFFFC36B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final remaining = (model.slowdown[player] / .9).clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          badge.left + 8,
          badge.bottom - 6,
          (badge.width - 16) * remaining,
          3,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFFFC36B),
    );
    _drawLabel(
      canvas,
      'SLOWED',
      center - const Offset(0, 2),
      const Color(0xFFFFFFFF),
      11,
      centered: true,
      rotation: top ? math.pi : 0,
    );
  }

  void _drawFinishPresentation(Canvas canvas, LaneDashResult result) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 360, 600),
      Paint()..color = const Color(0x85040B18),
    );
    if (result == LaneDashResult.draw || result == LaneDashResult.timeout) {
      _drawFinishCard(
        canvas,
        center: const Offset(180, 238),
        title: 'PHOTO FINISH',
        subtitle: 'DRAW',
        color: const Color(0xFFFFD166),
        rotation: math.pi,
      );
      _drawFinishCard(
        canvas,
        center: const Offset(180, 362),
        title: 'PHOTO FINISH',
        subtitle: 'DRAW',
        color: const Color(0xFFFFD166),
      );
      return;
    }
    final winner = result == LaneDashResult.playerOne ? 0 : 1;
    final top = winner == 1;
    _drawFinishCard(
      canvas,
      center: Offset(180, top ? 150 : 450),
      title: session.options.playerLabel(winner).toUpperCase(),
      subtitle: 'WINS!',
      color: winner == 0
          ? const Color(0xFF29C9FF)
          : session.options.mode == PlayMode.friend
          ? const Color(0xFFFF7043)
          : const Color(0xFFFFD166),
      rotation: top ? math.pi : 0,
    );
  }

  void _drawFinishCard(
    Canvas canvas, {
    required Offset center,
    required String title,
    required String subtitle,
    required Color color,
    double rotation = 0,
  }) {
    final card = Rect.fromCenter(center: center, width: 286, height: 104);
    canvas.drawRRect(
      RRect.fromRectAndRadius(card, const Radius.circular(24)),
      Paint()..color = const Color(0xE80A1830),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(card, const Radius.circular(24)),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    _drawLabel(
      canvas,
      title,
      center - const Offset(0, 20),
      color,
      18,
      centered: true,
      rotation: rotation,
    );
    _drawLabel(
      canvas,
      subtitle,
      center + const Offset(0, 17),
      const Color(0xFFFFFFFF),
      30,
      centered: true,
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

  void _drawObstacle(
    Canvas canvas,
    LaneObstacleKind kind,
    Offset center, {
    required bool top,
  }) {
    final size = switch (kind) {
      LaneObstacleKind.cone => const Size(32, 40),
      LaneObstacleKind.box => const Size(43, 43),
      LaneObstacleKind.barrier ||
      LaneObstacleKind.barricade => const Size(72, 42),
      LaneObstacleKind.rock || LaneObstacleKind.tires => const Size(48, 42),
      LaneObstacleKind.car => const Size(49, 69),
      LaneObstacleKind.van => const Size(53, 74),
      LaneObstacleKind.truck => const Size(57, 80),
    };
    _drawSprite(
      canvas,
      obstacleSpriteForKind(kind),
      center,
      size,
      rotation: top ? math.pi : 0,
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
