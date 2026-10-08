import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../../core/haptic_service.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'air_hockey_bot.dart';
import 'air_hockey_model.dart';

/// Flame adapter for Air Hockey simulation, rendering, and match reporting.
class AirHockeyGame extends Game {
  AirHockeyGame(this.session)
    : model = AirHockeyModel(winningScore: session.options.winningScore),
      bot = session.options.mode == PlayMode.bot
          ? AirHockeyBot(session.options.botDifficulty!)
          : null;

  final MatchSession session;
  final AirHockeyModel model;
  final AirHockeyBot? bot;
  bool _stopped = false;
  int _hits = 0;
  int _wallHits = 0;
  int _total = 0;
  double _paddleHitEffect = 0;
  double _wallHitEffect = 0;
  double _goalEffect = 0;
  int? _scoringPlayer;
  final Map<String, ui.Image> _sprites = {};

  static const _assetPaths = <String, String>{
    'paddle-red': 'assets/games/air_hockey/paddle_red.png',
    'paddle-blue': 'assets/games/air_hockey/paddle_blue.png',
    'puck': 'assets/games/air_hockey/puck.png',
    'puck-glow': 'assets/games/air_hockey/puck_glow.png',
    'trail-red': 'assets/games/air_hockey/puck_trail_red.png',
    'trail-blue': 'assets/games/air_hockey/puck_trail_blue.png',
    'puck-hit': 'assets/games/air_hockey/puck_hit_spark.png',
    'goal-confetti': 'assets/games/air_hockey/goal_confetti.png',
    'goal-flash': 'assets/games/air_hockey/goal_flash.png',
    'wall-red': 'assets/games/air_hockey/wall_hit_red.png',
    'wall-blue': 'assets/games/air_hockey/wall_hit_blue.png',
    'goal-frame-red': 'assets/games/air_hockey/goal_frame_red.png',
    'goal-frame-blue': 'assets/games/air_hockey/goal_frame_blue.png',
    'goal-net-red': 'assets/games/air_hockey/goal_net_red.png',
    'goal-net-blue': 'assets/games/air_hockey/goal_net_blue.png',
  };

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await Future.wait(
      _assetPaths.entries.map((entry) async {
        final data = await rootBundle.load(entry.value);
        _sprites[entry.key] = await decodeImageFromList(
          data.buffer.asUint8List(),
        );
      }),
    );
  }

  void resetMatch() {
    model.reset();
    bot?.reset();
    _hits = 0;
    _wallHits = 0;
    _total = 0;
    _paddleHitEffect = 0;
    _wallHitEffect = 0;
    _goalEffect = 0;
    _scoringPlayer = null;
  }

  void stopMatch() {
    _stopped = true;
    pauseEngine();
  }

  @override
  Color backgroundColor() => const Color(0xFF142333);

  @override
  void update(double dt) {
    if (_stopped || session.phase != MatchPhase.playing) return;
    _paddleHitEffect = math.max(0, _paddleHitEffect - dt);
    _wallHitEffect = math.max(0, _wallHitEffect - dt);
    _goalEffect = math.max(0, _goalEffect - dt);
    bot?.update(model, dt);
    model.update(dt);
    if (model.hitCount != _hits) {
      _hits = model.hitCount;
      _paddleHitEffect = .18;
      SoundEffects.play(SoundEffect.impactSoft);
      HapticEffects.paddleHit();
    }
    if (model.wallHitCount != _wallHits) {
      _wallHits = model.wallHitCount;
      _wallHitEffect = .15;
    }
    final next = model.scores[0] + model.scores[1];
    if (next != _total) {
      _total = next;
      _scoringPlayer = model.scores[0] > session.scores[0] ? 0 : 1;
      _goalEffect = .9;
      if (model.winner == null) {
        SoundEffects.play(
          scoreEffectForParticipant(session.options, _scoringPlayer!),
        );
      }
      session.reportScore(
        model.scores[0],
        model.scores[1],
        winner: model.winner,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    if (size.x <= 0) return;
    canvas.save();
    canvas.scale(size.x / 360, size.y / 600);
    final rink = const Rect.fromLTWH(8, 8, 344, 584);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rink, const Radius.circular(22)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF35172A), Color(0xFF071B31), Color(0xFF082D4F)],
          stops: [0, .5, 1],
        ).createShader(rink),
    );
    final line = Paint()
      ..color = const Color(0xFF5ECFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rink, const Radius.circular(22)),
      line,
    );
    _drawGoal(canvas, top: true);
    _drawGoal(canvas, top: false);
    canvas.drawLine(const Offset(8, 300), const Offset(352, 300), line);
    canvas.drawCircle(const Offset(180, 300), 54, line);
    canvas.drawCircle(
      const Offset(180, 300),
      5,
      Paint()..color = const Color(0xFFFFD54F),
    );

    final speed = math.sqrt(
      model.velocity.x * model.velocity.x + model.velocity.y * model.velocity.y,
    );
    if (speed > 220 && model.lastTouchPlayer != null) {
      final angle = math.atan2(model.velocity.y, model.velocity.x) + .42;
      _drawSprite(
        canvas,
        model.lastTouchPlayer == 0 ? 'trail-blue' : 'trail-red',
        Offset(model.puck.x, model.puck.y),
        const Size(105, 70),
        rotation: angle,
        opacity: .6,
      );
    }

    for (var player = 0; player < 2; player++) {
      final mallet = model.mallets[player];
      _drawSprite(
        canvas,
        player == 0 ? 'paddle-blue' : 'paddle-red',
        Offset(mallet.x, mallet.y),
        const Size(64, 60),
      );
    }
    _drawSprite(
      canvas,
      'puck-glow',
      Offset(model.puck.x, model.puck.y),
      const Size(39, 36),
      opacity: .72,
    );
    _drawSprite(
      canvas,
      'puck',
      Offset(model.puck.x, model.puck.y),
      const Size(29, 27),
    );

    if (_paddleHitEffect > 0) {
      _drawSprite(
        canvas,
        'puck-hit',
        Offset(model.puck.x, model.puck.y),
        const Size(88, 78),
        opacity: (_paddleHitEffect / .18).clamp(0, 1).toDouble(),
      );
    }
    if (_wallHitEffect > 0 && model.lastWallHit != null) {
      final hit = model.lastWallHit!;
      _drawSprite(
        canvas,
        hit.y < 300 ? 'wall-red' : 'wall-blue',
        Offset(hit.x, hit.y),
        const Size(82, 68),
        opacity: (_wallHitEffect / .15).clamp(0, 1).toDouble(),
      );
    }
    if (_goalEffect > 0 && _scoringPlayer != null) {
      final center = Offset(180, _scoringPlayer == 0 ? 42 : 558);
      final opacity = (_goalEffect / .9).clamp(0, 1).toDouble();
      _drawSprite(
        canvas,
        'goal-flash',
        center,
        const Size(170, 120),
        opacity: opacity,
      );
      _drawSprite(
        canvas,
        'goal-confetti',
        center,
        const Size(190, 130),
        opacity: opacity,
      );
    }
    canvas.restore();
  }

  void _drawGoal(Canvas canvas, {required bool top}) {
    final center = Offset(180, top ? 18 : 582);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (!top) canvas.rotate(math.pi);
    _drawSprite(
      canvas,
      top ? 'goal-net-red' : 'goal-net-blue',
      const Offset(0, 0),
      const Size(162, 74),
      opacity: .72,
    );
    _drawSprite(
      canvas,
      top ? 'goal-frame-red' : 'goal-frame-blue',
      const Offset(0, 0),
      const Size(168, 78),
    );
    canvas.restore();
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
    final target = Rect.fromCenter(
      center: Offset.zero,
      width: drawSize.width,
      height: drawSize.height,
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      target,
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    canvas.restore();
  }
}
