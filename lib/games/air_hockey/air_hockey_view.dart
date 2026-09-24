import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import '../../core/haptic_service.dart';
import 'air_hockey_model.dart';

class AirHockeyView extends StatefulWidget {
  const AirHockeyView({
    required this.session,
    required this.options,
    super.key,
  });
  final MatchSession session;
  final MatchOptions options;
  @override
  State<AirHockeyView> createState() => _AirHockeyViewState();
}

class _AirHockeyViewState extends State<AirHockeyView> {
  late final _AirHockeyGame game;
  final pointers = <int, int>{};
  int _round = -1;
  @override
  void initState() {
    super.initState();
    game = _AirHockeyGame(widget.session);
    widget.session.addListener(_syncSession);
    _syncSession();
  }

  void _syncSession() {
    if (_round != widget.session.round) {
      _round = widget.session.round;
      pointers.clear();
      game.resetMatch();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_syncSession);
    game.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = math.min(c.maxWidth, c.maxHeight * 0.6),
          left = (c.maxWidth - w) / 2;
      void move(int id, Offset p) {
        final player = pointers[id];
        if (player == null) return;
        game.model.moveMallet(
          player,
          (p.dx - left) / w * 360,
          p.dy / c.maxHeight * 600,
        );
      }

      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (widget.session.phase != MatchPhase.playing) return;
          final p = e.localPosition.dy < c.maxHeight / 2 ? 1 : 0;
          if (widget.options.mode == PlayMode.bot && p == 1) return;
          if (pointers.containsValue(p)) return;
          pointers[e.pointer] = p;
          move(e.pointer, e.localPosition);
        },
        onPointerMove: (e) => move(e.pointer, e.localPosition),
        onPointerUp: (e) => pointers.remove(e.pointer),
        onPointerCancel: (e) => pointers.remove(e.pointer),
        child: Center(
          child: AspectRatio(aspectRatio: .6, child: GameWidget(game: game)),
        ),
      );
    },
  );
}

class _AirHockeyGame extends Game {
  _AirHockeyGame(this.session)
    : model = AirHockeyModel(winningScore: session.options.winningScore);
  final MatchSession session;
  final AirHockeyModel model;
  bool stopped = false;
  int hits = 0, total = 0;

  void resetMatch() {
    model.reset();
    hits = 0;
    total = 0;
  }

  void stop() {
    stopped = true;
    pauseEngine();
  }

  @override
  Color backgroundColor() => const Color(0xFF142333);
  @override
  void update(double dt) {
    if (stopped || session.phase != MatchPhase.playing) return;
    if (session.options.mode == PlayMode.bot) {
      final puck = model.puck;
      final incoming = puck.y < 260 && model.velocity.y < 0;
      if (incoming) {
        // Meet an incoming puck below and to one side of its path. A centred
        // mallet produces a vertical rebound that can trap the puck against
        // the end rail; this offset gives the return a horizontal angle.
        final side = model.velocity.x >= 0 ? -62.0 : 62.0;
        final targetX = (puck.x + side).clamp(
          AirHockeyModel.malletRadius,
          AirHockeyModel.width - AirHockeyModel.malletRadius,
        );
        final targetY = (puck.y + 64).clamp(90.0, 230.0);
        model.moveMallet(1, targetX.toDouble(), targetY.toDouble());
      } else {
        model.moveMallet(1, AirHockeyModel.width / 2, 155);
      }
    }
    model.update(dt);
    if (model.hitCount != hits) {
      hits = model.hitCount;
      SoundEffects.play(SoundEffect.paddleHit);
      HapticEffects.paddleHit();
    }
    final next = model.scores[0] + model.scores[1];
    if (next != total) {
      total = next;
      SoundEffects.play(
        model.winner == null ? SoundEffect.score : SoundEffect.result,
      );
      session.reportScore(
        model.scores[0],
        model.scores[1],
        winner: model.winner,
      );
    }
  }

  @override
  void render(Canvas c) {
    if (size.x <= 0) return;
    c.save();
    c.scale(size.x / 360, size.y / 600);
    final line = Paint()
      ..color = const Color(0xFF304253)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    c.drawRect(const Rect.fromLTWH(8, 8, 344, 584), line);
    final goalLeft = (360 - AirHockeyModel.goalWidth) / 2;
    final goalPaint = Paint()
      ..color = const Color(0xFF0D1824)
      ..style = PaintingStyle.fill;
    c.drawRect(
      Rect.fromLTWH(goalLeft, 0, AirHockeyModel.goalWidth, 11),
      goalPaint,
    );
    c.drawRect(
      Rect.fromLTWH(goalLeft, 589, AirHockeyModel.goalWidth, 11),
      goalPaint,
    );
    c.drawLine(
      Offset(goalLeft, 8),
      Offset(goalLeft + AirHockeyModel.goalWidth, 8),
      line,
    );
    c.drawLine(
      Offset(goalLeft, 592),
      Offset(goalLeft + AirHockeyModel.goalWidth, 592),
      line,
    );
    c.drawLine(const Offset(8, 300), const Offset(352, 300), line);
    c.drawCircle(const Offset(180, 300), 54, line);
    for (var p = 0; p < 2; p++) {
      final m = model.mallets[p];
      c.drawCircle(
        Offset(m.x, m.y),
        AirHockeyModel.malletRadius,
        Paint()
          ..color = p == 0 ? const Color(0xFF9DF5CF) : const Color(0xFFFF968A),
      );
    }
    c.drawCircle(
      Offset(model.puck.x, model.puck.y),
      AirHockeyModel.puckRadius,
      Paint()..color = Colors.white,
    );
    c.restore();
  }
}
