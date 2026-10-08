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
      final mirrored = top && session.options.mode == PlayMode.friend;
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
      _drawRoad(canvas, player: player, mirrored: mirrored, panelTop: panelTop);
      final runnerY = mirrored ? 66.0 : (top ? 234.0 : 534.0);
      for (final obstacle in model.obstaclesFor(player)) {
        final gap = model.obstacleGap(player, obstacle);
        if (gap < -80 || gap > 650) continue;
        final y = mirrored ? runnerY + gap * 1.15 : runnerY - gap * 1.15;
        for (final lane in obstacle.blockedLanes) {
          if (gap > 0 && gap < 155) {
            _drawObstacleWarning(
              canvas,
              center: Offset(60 + 120.0 * lane, y),
              strength: (1 - gap / 155).clamp(0.0, 1.0),
            );
          }
          _drawObstacle(
            canvas,
            obstacle.kind,
            Offset(60 + 120.0 * lane, y),
            mirrored: mirrored,
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
        mirrored: mirrored,
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
        mirrored: mirrored,
      );
      final hudY = top ? 16.0 : 322.0;
      final participant = session.options.playerLabel(player).toUpperCase();
      if (mirrored) {
        _drawLabel(
          canvas,
          participant,
          const Offset(72, 18),
          color,
          14,
          centered: true,
          rotation: math.pi,
        );
      } else {
        _drawLabel(canvas, participant, Offset(12, hudY), color, 14);
      }
      final bar = Rect.fromLTWH(18, top ? 278 : 304, 314, 12);
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
        7,
        Paint()..color = const Color(0xFFFFFFFF),
      );
      _drawFinishFlag(
        canvas,
        Offset(342, bar.center.dy),
        rotation: mirrored ? math.pi : 0,
      );
      if (model.slowdown[player] > 0) {
        _drawSlowdownBadge(
          canvas,
          player: player,
          top: top,
          mirrored: mirrored,
        );
      }
      _drawHitIndicator(
        canvas,
        count: model.collisionCount[player],
        center: Offset(322, top ? 18 : 322),
        rotation: mirrored ? math.pi : 0,
      );
      if (_collisionEffect[player] > 0) {
        final pulse = (_collisionEffect[player] / .48).clamp(0.0, 1.0);
        canvas.drawRect(
          Rect.fromLTWH(2, panelTop + 2, 356, 296),
          Paint()
            ..color = const Color(0xFFFF3B30).withValues(alpha: pulse * .75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5,
        );
      }
      if (model.countdown > 0 &&
          (player == 0 || session.options.mode == PlayMode.friend)) {
        _drawControlHint(
          canvas,
          center: Offset(runnerX, runnerY),
          mirrored: mirrored,
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
      final mirrored = top && session.options.mode == PlayMode.friend;
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
      final rotation = mirrored ? math.pi : 0.0;
      _drawLabel(
        canvas,
        label,
        center + Offset(0, detail == null ? 0 : (mirrored ? 14 : -14)),
        accent.withValues(alpha: opacity),
        detail == null ? 34 : 23,
        centered: true,
        rotation: rotation,
      );
      if (detail != null) {
        _drawLabel(
          canvas,
          detail,
          center + Offset(0, mirrored ? -17 : 17),
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
    required bool mirrored,
    required double panelTop,
  }) {
    canvas.drawRect(
      Rect.fromLTWH(0, panelTop, 360, 300),
      Paint()..color = const Color(0xFF182536),
    );
    canvas.drawRect(
      Rect.fromLTWH(5, panelTop, 7, 300),
      Paint()..color = const Color(0xFFFF5A52),
    );
    canvas.drawRect(
      Rect.fromLTWH(348, panelTop, 7, 300),
      Paint()..color = const Color(0xFFFF5A52),
    );
    const dashHeight = 34.0;
    const dashGap = 28.0;
    final period = dashHeight + dashGap;
    final rawOffset = (model.distance[player] * 2.2) % period;
    final offset = mirrored ? -rawOffset : rawOffset;
    for (final x in [120.0, 240.0]) {
      for (
        var y = panelTop - period;
        y < panelTop + 300 + period;
        y += period
      ) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 3, y + offset, 6, dashHeight),
            const Radius.circular(3),
          ),
          Paint()..color = const Color(0xB3EAF4FF),
        );
      }
    }
    canvas.drawRect(
      Rect.fromLTWH(0, panelTop, 360, 300),
      Paint()
        ..shader = LinearGradient(
          begin: mirrored ? Alignment.topCenter : Alignment.bottomCenter,
          end: mirrored ? Alignment.bottomCenter : Alignment.topCenter,
          colors: const [Color(0x8A07111F), Color(0x0007111F)],
        ).createShader(Rect.fromLTWH(0, panelTop, 360, 300)),
    );
  }

  void _drawRunner(
    Canvas canvas, {
    required int player,
    required Offset center,
    required bool mirrored,
    required Color color,
  }) {
    final rotation = mirrored ? math.pi : 0.0;
    final direction = mirrored ? -1.0 : 1.0;
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
    required bool mirrored,
  }) {
    final effect = _collisionEffect[player];
    if (effect > 0) {
      final opacity = (effect / .48).clamp(0, 1).toDouble();
      final rotation = mirrored ? math.pi : 0.0;
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
      final direction = mirrored ? -1.0 : 1.0;
      _drawSprite(
        canvas,
        'hit_smoke',
        center + Offset(0, 27 * direction),
        const Size(58, 49),
        rotation: mirrored ? math.pi : 0,
        opacity: (model.slowdown[player] / .9).clamp(.18, .62).toDouble(),
      );
    }
  }

  void _drawSlowdownBadge(
    Canvas canvas, {
    required int player,
    required bool top,
    required bool mirrored,
  }) {
    final center = Offset(180, top ? (mirrored ? 254 : 52) : 346);
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
      rotation: mirrored ? math.pi : 0,
    );
  }

  void _drawControlHint(
    Canvas canvas, {
    required Offset center,
    required bool mirrored,
  }) {
    final pulse = .55 + .45 * math.sin(model.countdown * math.pi * 2).abs();
    canvas.save();
    canvas.translate(center.dx, center.dy + (mirrored ? -58 : 58));
    if (mirrored) canvas.rotate(math.pi);
    for (final direction in [-1.0, 1.0]) {
      final x = 50 * direction;
      final arrow = Path()
        ..moveTo(x + 10 * direction, 0)
        ..lineTo(x - 6 * direction, -11)
        ..moveTo(x + 10 * direction, 0)
        ..lineTo(x - 6 * direction, 11);
      canvas.drawPath(
        arrow,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  void _drawObstacleWarning(
    Canvas canvas, {
    required Offset center,
    required double strength,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 92, height: 98),
        const Radius.circular(24),
      ),
      Paint()
        ..color = const Color(0xFFFF3B30).withValues(alpha: strength * .22),
    );
  }

  void _drawHitIndicator(
    Canvas canvas, {
    required int count,
    required Offset center,
    required double rotation,
  }) {
    if (count == 0) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotation != 0) canvas.rotate(rotation);
    canvas.drawCircle(
      Offset.zero,
      13,
      Paint()..color = const Color(0xD9B4232E),
    );
    canvas.drawLine(
      const Offset(-5, -5),
      const Offset(5, 5),
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(5, -5),
      const Offset(-5, 5),
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    if (count > 1) {
      _drawLabel(
        canvas,
        '$count',
        const Offset(18, 0),
        const Color(0xFFFFFFFF),
        13,
        centered: true,
      );
    }
    canvas.restore();
  }

  void _drawFinishFlag(Canvas canvas, Offset center, {double rotation = 0}) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotation != 0) canvas.rotate(rotation);
    canvas.drawLine(
      const Offset(-7, -10),
      const Offset(-7, 11),
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 2,
    );
    const cell = 5.0;
    for (var row = 0; row < 2; row++) {
      for (var column = 0; column < 3; column++) {
        canvas.drawRect(
          Rect.fromLTWH(-5 + column * cell, -10 + row * cell, cell, cell),
          Paint()
            ..color = (row + column).isEven
                ? const Color(0xFFFFFFFF)
                : const Color(0xFF101B28),
        );
      }
    }
    canvas.restore();
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
        rotation: session.options.mode == PlayMode.friend ? math.pi : 0,
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
    final mirrored = top && session.options.mode == PlayMode.friend;
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
      rotation: mirrored ? math.pi : 0,
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
    required bool mirrored,
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
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(0, 8),
        width: size.width * .82,
        height: size.height * .36,
      ),
      Paint()..color = const Color(0x66000000),
    );
    if (kind.isTraffic) {
      final direction = mirrored ? -1.0 : 1.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center + Offset(0, 36 * direction),
            width: size.width * .55,
            height: 38,
          ),
          const Radius.circular(12),
        ),
        Paint()
          ..shader =
              LinearGradient(
                begin: mirrored ? Alignment.topCenter : Alignment.bottomCenter,
                end: mirrored ? Alignment.bottomCenter : Alignment.topCenter,
                colors: const [Color(0x0000C8FF), Color(0x7000C8FF)],
              ).createShader(
                Rect.fromCenter(
                  center: center + Offset(0, 36 * direction),
                  width: size.width * .55,
                  height: 38,
                ),
              ),
      );
    }
    _drawSprite(
      canvas,
      obstacleSpriteForKind(kind),
      center,
      size,
      rotation: mirrored ? math.pi : 0,
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
