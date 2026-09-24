import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

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
  int _total = 0;

  void resetMatch() {
    model.reset();
    bot?.reset();
    _hits = 0;
    _total = 0;
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
    bot?.update(model, dt);
    model.update(dt);
    if (model.hitCount != _hits) {
      _hits = model.hitCount;
      SoundEffects.play(SoundEffect.paddleHit);
      HapticEffects.paddleHit();
    }
    final next = model.scores[0] + model.scores[1];
    if (next != _total) {
      _total = next;
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
  void render(Canvas canvas) {
    if (size.x <= 0) return;
    canvas.save();
    canvas.scale(size.x / 360, size.y / 600);
    final line = Paint()
      ..color = const Color(0xFF304253)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRect(const Rect.fromLTWH(8, 8, 344, 584), line);
    final goalLeft = (360 - AirHockeyModel.goalWidth) / 2;
    final goalPaint = Paint()
      ..color = const Color(0xFF0D1824)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(goalLeft, 0, AirHockeyModel.goalWidth, 11),
      goalPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(goalLeft, 589, AirHockeyModel.goalWidth, 11),
      goalPaint,
    );
    canvas.drawLine(
      Offset(goalLeft, 8),
      Offset(goalLeft + AirHockeyModel.goalWidth, 8),
      line,
    );
    canvas.drawLine(
      Offset(goalLeft, 592),
      Offset(goalLeft + AirHockeyModel.goalWidth, 592),
      line,
    );
    canvas.drawLine(const Offset(8, 300), const Offset(352, 300), line);
    canvas.drawCircle(const Offset(180, 300), 54, line);
    for (var player = 0; player < 2; player++) {
      final mallet = model.mallets[player];
      canvas.drawCircle(
        Offset(mallet.x, mallet.y),
        AirHockeyModel.malletRadius,
        Paint()
          ..color = player == 0
              ? const Color(0xFF9DF5CF)
              : const Color(0xFFFF968A),
      );
    }
    canvas.drawCircle(
      Offset(model.puck.x, model.puck.y),
      AirHockeyModel.puckRadius,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    canvas.restore();
  }
}
