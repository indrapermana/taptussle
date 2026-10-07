import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../../core/match_session.dart';
import '../../core/match_options.dart';
import '../../core/haptic_service.dart';
import '../../core/sound_service.dart';
import 'paddle_duel_bot.dart';
import 'paddle_duel_model.dart';

/// Flame owns frame scheduling and court rendering; Flutter owns the match UI.
class PaddleDuelGame extends Game {
  PaddleDuelGame({required this.session, math.Random? botRandom})
    : model = PaddleDuelModel(winningScore: session.options.winningScore),
      bot = session.options.mode == PlayMode.bot
          ? PaddleDuelBot(session.options.botDifficulty!, random: botRandom)
          : null;

  final PaddleDuelBot? bot;
  bool _stopped = false;
  PaddleDuelArtwork? artwork;
  double _hitEffectRemaining = 0;
  Offset _hitEffectCenter = Offset.zero;

  void resetMatch() {
    model.reset();
    bot?.reset();
    _hitEffectRemaining = 0;
  }

  void stopMatch() {
    _stopped = true;
    pauseEngine();
  }

  final MatchSession session;
  final PaddleDuelModel model;
  static const mint = Color(0xFF9DF5CF);
  static const coral = Color(0xFFFF968A);

  @override
  Color backgroundColor() => const Color(0xFF142333);

  @override
  void update(double dt) {
    if (_stopped ||
        session.phase != MatchPhase.playing ||
        dt <= 0 ||
        !dt.isFinite) {
      return;
    }
    var remaining = math.min(dt, .1);
    _hitEffectRemaining = math.max(0, _hitEffectRemaining - remaining);
    while (remaining > .000001) {
      final step = math.min(remaining, 1 / 120);
      final oldScores = List<int>.of(model.scores);
      final oldPaddleHits = model.paddleHitCount;
      bot?.update(model, step);
      model.update(step);
      remaining -= step;
      if (oldPaddleHits != model.paddleHitCount) {
        _hitEffectRemaining = .14;
        _hitEffectCenter = Offset(model.ballX, model.ballY);
        SoundEffects.play(SoundEffect.impactSoft);
        HapticEffects.paddleHit();
      }
      if (oldScores[0] != model.scores[0] || oldScores[1] != model.scores[1]) {
        bot?.reset();
        if (model.winner == null) {
          final scoringPlayer = model.scores[0] > oldScores[0] ? 0 : 1;
          SoundEffects.play(
            scoreEffectForParticipant(session.options, scoringPlayer),
          );
        }
        session.reportScore(
          model.scores[0],
          model.scores[1],
          winner: model.winner,
        );
        if (session.phase != MatchPhase.playing) break;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0) return;
    renderAtSize(canvas, Size(size.x, size.y));
  }

  /// Renders the fixed logical court into a caller-controlled output size.
  ///
  /// The presentation layer uses this to rasterize a physical render target
  /// independently from the Flutter layout size.
  void renderAtSize(Canvas canvas, Size outputSize) {
    if (outputSize.isEmpty) return;
    canvas.save();
    canvas.scale(
      outputSize.width / PaddleDuelModel.width,
      outputSize.height / PaddleDuelModel.height,
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
    _label(
      canvas,
      session.options.playerLabel(0).toUpperCase(),
      const Offset(180, 588),
      mint,
    );
    canvas.save();
    canvas.translate(180, 12);
    if (session.options.mode == PlayMode.friend) canvas.rotate(math.pi);
    _label(
      canvas,
      session.options.playerLabel(1).toUpperCase(),
      Offset.zero,
      coral,
    );
    canvas.restore();
    final sprites = artwork;
    for (var player = 0; player < 2; player++) {
      final center = Offset(
        model.paddles[player],
        player == 0 ? PaddleDuelModel.bottomY : PaddleDuelModel.topY,
      );
      final paddle = player == 0 ? sprites?.bluePaddle : sprites?.redPaddle;
      if (paddle == null) {
        final rect = Rect.fromCenter(
          center: center,
          width: PaddleDuelModel.paddleWidth,
          height: PaddleDuelModel.paddleHeight,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          Paint()..color = player == 0 ? mint : coral,
        );
      } else {
        _drawRotatedSprite(
          canvas,
          paddle,
          center: center,
          width: 104,
          height: 34,
        );
      }
    }
    final ballCenter = Offset(model.ballX, model.ballY);
    if (sprites == null) {
      canvas.drawCircle(
        ballCenter,
        PaddleDuelModel.radius + 5,
        Paint()..color = const Color(0x18FFFFFF),
      );
      canvas.drawCircle(
        ballCenter,
        PaddleDuelModel.radius,
        Paint()..color = const Color(0xFFFFFFFF),
      );
    } else {
      if (model.serveRemaining <= 0) {
        final angle = math.atan2(model.velocityY, model.velocityX);
        _drawRotatedSprite(
          canvas,
          sprites.ballTrail,
          center: ballCenter - Offset.fromDirection(angle, 13),
          width: 43,
          height: 20,
          angle: angle + math.pi / 4,
          opacity: .38,
        );
      }
      _drawSprite(
        canvas,
        sprites.ball,
        Rect.fromCenter(center: ballCenter, width: 31, height: 31),
      );
      if (_hitEffectRemaining > 0) {
        _drawSprite(
          canvas,
          sprites.hitBurst,
          Rect.fromCenter(center: _hitEffectCenter, width: 54, height: 54),
          opacity: (_hitEffectRemaining / .14).clamp(0, 1),
        );
      }
    }
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

  void _drawSprite(
    Canvas canvas,
    ui.Image image,
    Rect destination, {
    double opacity = 1,
  }) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      destination,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, opacity),
    );
  }

  void _drawRotatedSprite(
    Canvas canvas,
    ui.Image image, {
    required Offset center,
    required double width,
    required double height,
    double angle = math.pi / 2,
    double opacity = 1,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    _drawSprite(
      canvas,
      image,
      Rect.fromCenter(center: Offset.zero, width: height, height: width),
      opacity: opacity,
    );
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

class PaddleDuelArtwork {
  const PaddleDuelArtwork({
    required this.redPaddle,
    required this.bluePaddle,
    required this.ball,
    required this.hitBurst,
    required this.ballTrail,
  });

  final ui.Image redPaddle;
  final ui.Image bluePaddle;
  final ui.Image ball;
  final ui.Image hitBurst;
  final ui.Image ballTrail;

  void dispose() {
    redPaddle.dispose();
    bluePaddle.dispose();
    ball.dispose();
    hitBurst.dispose();
    ballTrail.dispose();
  }
}
