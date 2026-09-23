import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../core/match_session.dart';
import 'paddle_duel_model.dart';

/// Flame owns frame scheduling and court rendering; Flutter owns the match UI.
class PaddleDuelGame extends Game {
  PaddleDuelGame({required this.session, required int winningScore})
    : model = PaddleDuelModel(winningScore: winningScore);

  final MatchSession session;
  final PaddleDuelModel model;
  static const mint = Color(0xFF9DF5CF);
  static const coral = Color(0xFFFF968A);

  @override
  Color backgroundColor() => const Color(0xFF142333);

  @override
  void update(double dt) {
    if (session.phase != MatchPhase.playing) return;
    final oldTotal = model.scores[0] + model.scores[1];
    model.update(dt);
    if (oldTotal != model.scores[0] + model.scores[1]) {
      session.reportScore(
        model.scores[0],
        model.scores[1],
        winner: model.winner,
      );
    }
  }

  @override
  void render(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0) return;
    canvas.save();
    canvas.scale(
      size.x / PaddleDuelModel.width,
      size.y / PaddleDuelModel.height,
    );
    final line = Paint()
      ..color = const Color(0xFF304253)
      ..strokeWidth = 2;
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 360, 300),
      Paint()..color = const Color(0x0CFF968A),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 300, 360, 300),
      Paint()..color = const Color(0x0C9DF5CF),
    );
    for (double x = 12; x < 360; x += 20) {
      canvas.drawLine(Offset(x, 300), Offset(x + 10, 300), line);
    }
    canvas.drawCircle(
      const Offset(180, 300),
      44,
      Paint()
        ..color = const Color(0xFF304253)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(const Offset(1, 0), const Offset(1, 600), line);
    canvas.drawLine(const Offset(359, 0), const Offset(359, 600), line);
    _label(canvas, 'PLAYER 1', const Offset(180, 588), mint);
    canvas.save();
    canvas.translate(180, 12);
    canvas.rotate(3.141592653589793);
    _label(canvas, 'PLAYER 2', Offset.zero, coral);
    canvas.restore();
    for (var player = 0; player < 2; player++) {
      final rect = Rect.fromCenter(
        center: Offset(
          model.paddles[player],
          player == 0 ? PaddleDuelModel.bottomY : PaddleDuelModel.topY,
        ),
        width: PaddleDuelModel.paddleWidth,
        height: PaddleDuelModel.paddleHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()..color = player == 0 ? mint : coral,
      );
    }
    canvas.drawCircle(
      Offset(model.ballX, model.ballY),
      PaddleDuelModel.radius + 5,
      Paint()..color = const Color(0x18FFFFFF),
    );
    canvas.drawCircle(
      Offset(model.ballX, model.ballY),
      PaddleDuelModel.radius,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    if (model.serveRemaining > 0 && session.phase == MatchPhase.playing) {
      _label(
        canvas,
        'READY  ${model.serveRemaining.ceil()}',
        const Offset(180, 350),
        const Color(0xCCFFFFFF),
      );
    }
    canvas.restore();
  }

  void _label(Canvas canvas, String text, Offset center, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }
}
