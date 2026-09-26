import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

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
  var _reportedCountdown = 3;
  bool _stopped = false;

  void resetMatch() {
    model.reset();
    bot?.reset();
    _reportedProgress[0] = _reportedProgress[1] = 0;
    _reportedCollisions[0] = _reportedCollisions[1] = 0;
    _reportedCountdown = 3;
  }

  void stopMatch() {
    _stopped = true;
    pauseEngine();
  }

  void move(int player, int direction) => model.move(player, direction);

  @override
  Color backgroundColor() => const Color(0xFF142333);

  @override
  void update(double dt) {
    if (_stopped || session.phase != MatchPhase.playing) return;
    bot?.update(model, dt);
    model.update(dt);
    final countdown = model.countdown.ceil();
    if (countdown != _reportedCountdown) {
      _reportedCountdown = countdown;
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
            ? 'Both runners reached ${LaneDashModel.finishDistance.round()} m together. • Another round?'
            : 'The race ended level at ${model.distance[0].round()} m. • Another round?',
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
            '${model.distance[loser].round()} m. • Another round?',
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
      ..color = const Color(0xFF304253)
      ..strokeWidth = 3;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 360, 300),
      Paint()..color = const Color(0xFF182A3A),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 300, 360, 300),
      Paint()..color = const Color(0xFF11212F),
    );
    canvas.drawLine(const Offset(0, 300), const Offset(360, 300), divider);
    for (final top in [true, false]) {
      final panelTop = top ? 0.0 : 300.0;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, panelTop, 360, 300));
      for (var laneEdge = 0; laneEdge <= 3; laneEdge++) {
        final x = laneEdge * 120.0;
        canvas.drawLine(
          Offset(x, panelTop),
          Offset(x, panelTop + 300),
          divider,
        );
      }
      final player = top ? 1 : 0;
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
          ? const Color(0xFF9DF5CF)
          : const Color(0xFFFF968A);
      final runnerX = 60 + 120.0 * model.lanes[player];
      canvas.drawCircle(Offset(runnerX, runnerY), 19, Paint()..color = color);
      canvas.drawCircle(
        Offset(runnerX, runnerY),
        10,
        Paint()..color = const Color(0xFF142333),
      );
      final hudY = top ? 16.0 : 322.0;
      _drawLabel(
        canvas,
        top
            ? session.options.mode == PlayMode.bot
                  ? 'BOT'
                  : 'PLAYER 2'
            : 'PLAYER 1',
        Offset(12, hudY),
        color,
        12,
      );
      _drawLabel(
        canvas,
        '${model.distance[player].round()} / ${LaneDashModel.finishDistance.round()} m',
        Offset(348, hudY),
        const Color(0xFFFFFFFF),
        12,
        right: true,
      );
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
        );
      }
      _drawLabel(
        canvas,
        'HITS ${model.collisionCount[player]}',
        Offset(top ? 348 : 12, top ? 286 : 322),
        const Color(0xB3FFFFFF),
        10,
        right: !top,
      );
      canvas.restore();
    }
    if (model.countdown > 0) {
      _drawLabel(
        canvas,
        model.countdown.ceil().toString(),
        const Offset(180, 300),
        const Color(0xFFFFFFFF),
        56,
        centered: true,
      );
    }
    canvas.restore();
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
        ? point.dx - painter.width / 2
        : right
        ? point.dx - painter.width
        : point.dx;
    painter.paint(canvas, Offset(x, point.dy - painter.height / 2));
    painter.dispose();
  }
}
