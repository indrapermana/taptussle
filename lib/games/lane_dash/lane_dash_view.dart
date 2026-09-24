import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'lane_dash_model.dart';
import 'lane_dash_bot.dart';

class LaneDashView extends StatefulWidget {
  const LaneDashView({required this.session, required this.options, super.key});
  final MatchSession session;
  final MatchOptions options;
  @override
  State<LaneDashView> createState() => _LaneDashViewState();
}

class _LaneDashViewState extends State<LaneDashView> {
  late final _LaneGame game;
  int _round = -1;
  final Map<int, (int, Offset)> _swipes = {};
  @override
  void initState() {
    super.initState();
    game = _LaneGame(widget.session);
    widget.session.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (_round != widget.session.round) {
      _round = widget.session.round;
      _swipes.clear();
      game.resetMatch();
    } else if (widget.session.phase != MatchPhase.playing) {
      _swipes.clear();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_sync);
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Stack(
    fit: StackFit.expand,
    children: [
      GameWidget(game: game),
      Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (widget.session.phase != MatchPhase.playing) return;
          final player = event.localPosition.dy < context.size!.height / 2
              ? 1
              : 0;
          if (player == 1 && widget.options.mode == PlayMode.bot) return;
          _swipes[event.pointer] = (player, event.localPosition);
        },
        onPointerUp: (event) {
          final swipe = _swipes.remove(event.pointer);
          if (swipe == null || widget.session.phase != MatchPhase.playing) {
            return;
          }
          final delta = event.localPosition.dx - swipe.$2.dx;
          final threshold = (context.size!.width * .06).clamp(24.0, 48.0);
          if (delta.abs() < threshold) return;
          // The top runner faces the opposite direction, so its swipe is mirrored.
          final direction = delta.isNegative ? -1 : 1;
          game.move(swipe.$1, swipe.$1 == 1 ? -direction : direction);
        },
        onPointerCancel: (event) => _swipes.remove(event.pointer),
        child: const SizedBox.expand(),
      ),
    ],
  );
}

class _LaneGame extends Game {
  _LaneGame(this.session)
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
  void resetMatch() {
    model.reset();
    bot?.reset();
    _reportedProgress[0] = _reportedProgress[1] = 0;
  }

  void move(int p, int d) => model.move(p, d);
  @override
  Color backgroundColor() => const Color(0xFF142333);
  @override
  void update(double dt) {
    if (session.phase != MatchPhase.playing) return;
    bot?.update(model, dt);
    model.update(dt);
    final progress = [model.distance[0].round(), model.distance[1].round()];
    final r = model.result;
    if (r == LaneDashResult.draw || r == LaneDashResult.timeout) {
      SoundEffects.play(SoundEffect.result);
      session.reportNonPointResult(
        winner: null,
        scores: progress,
        details: r == LaneDashResult.draw
            ? 'Both runners reached ${LaneDashModel.finishDistance.round()} m together. • Another round?'
            : 'The race ended level at ${model.distance[0].round()} m. • Another round?',
      );
    } else if (r == LaneDashResult.playerOne || r == LaneDashResult.playerTwo) {
      SoundEffects.play(SoundEffect.result);
      final winner = r == LaneDashResult.playerOne ? 0 : 1;
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
  void render(Canvas c) {
    if (size.x <= 0 || size.y <= 0) return;
    c.save();
    c.scale(size.x / 360, size.y / 600);
    final divider = Paint()
      ..color = const Color(0xFF304253)
      ..strokeWidth = 3;
    c.drawRect(
      const Rect.fromLTWH(0, 0, 360, 300),
      Paint()..color = const Color(0xFF182A3A),
    );
    c.drawRect(
      const Rect.fromLTWH(0, 300, 360, 300),
      Paint()..color = const Color(0xFF11212F),
    );
    c.drawLine(const Offset(0, 300), const Offset(360, 300), divider);
    for (final top in [true, false]) {
      final panelTop = top ? 0.0 : 300.0;
      c.save();
      c.clipRect(Rect.fromLTWH(0, panelTop, 360, 300));
      for (var laneEdge = 0; laneEdge <= 3; laneEdge++) {
        final x = laneEdge * 120.0;
        c.drawLine(Offset(x, panelTop), Offset(x, panelTop + 300), divider);
      }
      final player = top ? 1 : 0;
      final runnerY = top ? 66.0 : 534.0;
      for (final obstacle in model.obstaclesFor(player)) {
        final gap = obstacle.distance - model.distance[player];
        if (gap < -5 || gap > 650) continue;
        final y = top ? runnerY + gap * 1.15 : runnerY - gap * 1.15;
        for (final lane in obstacle.blockedLanes) {
          _drawCone(c, 60 + 120.0 * lane, y);
        }
      }
      final color = player == 0
          ? const Color(0xFF9DF5CF)
          : const Color(0xFFFF968A);
      final runnerX = 60 + 120.0 * model.lanes[player];
      c.drawCircle(Offset(runnerX, runnerY), 19, Paint()..color = color);
      c.drawCircle(
        Offset(runnerX, runnerY),
        10,
        Paint()..color = const Color(0xFF142333),
      );
      final hudY = top ? 16.0 : 322.0;
      _drawLabel(
        c,
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
        c,
        '${model.distance[player].round()} / ${LaneDashModel.finishDistance.round()} m',
        Offset(348, hudY),
        Colors.white,
        12,
        right: true,
      );
      final bar = Rect.fromLTWH(12, top ? 281 : 305, 336, 5);
      c.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(3)),
        Paint()..color = Colors.white24,
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
      c.drawRRect(
        RRect.fromRectAndRadius(progress, const Radius.circular(3)),
        Paint()..color = color,
      );
      if (model.slowdown[player] > 0) {
        _drawLabel(
          c,
          'HIT • SLOW',
          Offset(180, top ? 258 : 342),
          const Color(0xFFFFC36B),
          13,
        );
      }
      _drawLabel(
        c,
        'HITS ${model.collisionCount[player]}',
        Offset(top ? 348 : 12, top ? 286 : 322),
        Colors.white70,
        10,
        right: !top,
      );
      c.restore();
    }
    if (model.countdown > 0) {
      final label = model.countdown.ceil().toString();
      _drawLabel(
        c,
        label,
        const Offset(180, 300),
        Colors.white,
        56,
        centered: true,
      );
    }
    c.restore();
  }

  void _drawCone(Canvas canvas, double x, double y) {
    final path = Path()
      ..moveTo(x, y - 13)
      ..lineTo(x + 10, y + 11)
      ..lineTo(x - 10, y + 11)
      ..close();
    canvas.drawShadow(path, Colors.black54, 3, true);
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
        ..color = Colors.white
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
