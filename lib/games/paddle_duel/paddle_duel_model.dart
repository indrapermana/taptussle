import 'dart:math' as math;

/// Deterministic simulation in a fixed 360 × 600 logical court.
/// No Flutter/Flame dependency: rendering and input are adapters around this.
class PaddleDuelModel {
  PaddleDuelModel({required this.winningScore}) : assert(winningScore > 0);

  static const width = 360.0;
  static const height = 600.0;
  static const paddleWidth = 84.0;
  static const paddleHeight = 12.0;
  static const topY = 42.0;
  static const bottomY = height - topY;
  static const radius = 7.0;
  final int winningScore;
  final paddles = [width / 2, width / 2];
  final scores = [0, 0];
  double ballX = width / 2;
  double ballY = height / 2;
  double velocityX = 0;
  double velocityY = 0;
  double serveRemaining = 1.5;
  int? winner;
  int _serveDirection = 1;

  void reset() {
    scores.fillRange(0, 2, 0);
    paddles.fillRange(0, 2, width / 2);
    winner = null;
    _serveDirection = 1;
    _serve();
  }

  void movePaddle(int player, double x) {
    paddles[player] = x.clamp(paddleWidth / 2, width - paddleWidth / 2);
  }

  void _serve() {
    ballX = width / 2;
    ballY = height / 2;
    velocityX = 115 * ((scores[0] + scores[1]).isEven ? 1 : -1);
    velocityY = 245.0 * _serveDirection;
    serveRemaining = 1.5;
  }

  void update(double dt) {
    if (winner != null || dt <= 0 || !dt.isFinite) return;
    // Discard long stalls instead of teleporting the ball through the court.
    var remaining = math.min(dt, .1);
    if (serveRemaining > 0) {
      final consumed = math.min(serveRemaining, remaining);
      serveRemaining -= consumed;
      remaining -= consumed;
    }
    // Small fixed-size substeps prevent tunnelling at the maximum ball speed.
    while (remaining > 0.000001 && winner == null && serveRemaining <= 0) {
      final step = math.min(remaining, 1 / 240);
      _step(step);
      remaining -= step;
    }
  }

  void _step(double dt) {
    final previousY = ballY;
    ballX += velocityX * dt;
    ballY += velocityY * dt;
    if (ballX < radius) {
      ballX = 2 * radius - ballX;
      velocityX = velocityX.abs();
    } else if (ballX > width - radius) {
      ballX = 2 * (width - radius) - ballX;
      velocityX = -velocityX.abs();
    }

    final bottomFace = bottomY - paddleHeight / 2 - radius;
    final topFace = topY + paddleHeight / 2 + radius;
    if (velocityY > 0 &&
        previousY <= bottomFace &&
        ballY >= bottomFace &&
        (ballX - paddles[0]).abs() <= paddleWidth / 2 + radius) {
      ballY = bottomFace;
      _bounce(0, -1);
    } else if (velocityY < 0 &&
        previousY >= topFace &&
        ballY <= topFace &&
        (ballX - paddles[1]).abs() <= paddleWidth / 2 + radius) {
      ballY = topFace;
      _bounce(1, 1);
    }

    if (ballY < -radius) {
      _point(0);
    } else if (ballY > height + radius) {
      _point(1);
    }
  }

  void _bounce(int player, int direction) {
    final offset = ((ballX - paddles[player]) / (paddleWidth / 2)).clamp(
      -1.0,
      1.0,
    );
    final angle = offset * math.pi / 3;
    final speed = math.min(
      500.0,
      math.sqrt(velocityX * velocityX + velocityY * velocityY) * 1.055,
    );
    velocityX = math.sin(angle) * speed;
    velocityY = direction * math.cos(angle) * speed;
  }

  void _point(int player) {
    scores[player]++;
    if (scores[player] >= winningScore) {
      winner = player;
      return;
    }
    // Serve toward the player who conceded the point.
    _serveDirection = player == 0 ? -1 : 1;
    _serve();
  }
}
