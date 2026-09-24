import 'dart:math' as math;

class AirHockeyModel {
  AirHockeyModel({required this.winningScore});
  static const width = 360.0,
      height = 600.0,
      malletRadius = 28.0,
      puckRadius = 12.0,
      goalWidth = 150.0;
  final int winningScore;
  final scores = [0, 0];
  final mallets = [math.Point<double>(180, 500), math.Point<double>(180, 100)];
  final targets = [math.Point<double>(180, 500), math.Point<double>(180, 100)];
  math.Point<double> puck = math.Point(180, 300);
  math.Point<double> velocity = const math.Point(0, 0);
  int? winner;
  int hitCount = 0;
  void reset() {
    scores[0] = scores[1] = 0;
    mallets[0] = const math.Point(180, 500);
    mallets[1] = const math.Point(180, 100);
    targets[0] = mallets[0];
    targets[1] = mallets[1];
    winner = null;
    hitCount = 0;
    _serve(0);
  }

  void moveMallet(int player, double x, double y) {
    final minY = player == 0 ? height / 2 + malletRadius : malletRadius;
    final maxY = player == 0
        ? height - malletRadius
        : height / 2 - malletRadius;
    targets[player] = math.Point(
      x.clamp(malletRadius, width - malletRadius),
      y.clamp(minY, maxY),
    );
  }

  void update(double dt) {
    if (winner != null) return;
    var left = math.min(dt, .1);
    while (left > .000001 && winner == null) {
      final step = math.min(left, 1 / 240);
      _step(step);
      left -= step;
    }
  }

  void _step(double dt) {
    for (var p = 0; p < 2; p++) {
      final from = mallets[p], to = targets[p];
      final dx = to.x - from.x, dy = to.y - from.y;
      final distance = math.sqrt(dx * dx + dy * dy);
      final move = math.min(distance, 520 * dt);
      if (distance > .001) {
        mallets[p] = math.Point(
          from.x + dx / distance * move,
          from.y + dy / distance * move,
        );
      }
    }
    puck = math.Point(puck.x + velocity.x * dt, puck.y + velocity.y * dt);
    final goalMin = (width - goalWidth) / 2, goalMax = goalMin + goalWidth;
    if (puck.x < puckRadius || puck.x > width - puckRadius) {
      velocity = math.Point(-velocity.x, velocity.y);
    }
    if ((puck.y < puckRadius && (puck.x < goalMin || puck.x > goalMax)) ||
        (puck.y > height - puckRadius &&
            (puck.x < goalMin || puck.x > goalMax))) {
      velocity = math.Point(velocity.x, -velocity.y);
    }
    // Side rails are solid. The ends are only solid outside a goal mouth, so a
    // puck travelling through the mouth can cross the scoring line.
    puck = math.Point(puck.x.clamp(puckRadius, width - puckRadius), puck.y);
    for (final mallet in mallets) {
      final dx = puck.x - mallet.x, dy = puck.y - mallet.y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > 0 && d < malletRadius + puckRadius) {
        final nx = dx / d, ny = dy / d;
        puck = math.Point(
          mallet.x + nx * (malletRadius + puckRadius),
          mallet.y + ny * (malletRadius + puckRadius),
        );
        final speed = math.max(
          260,
          math.min(
            700,
            math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y) * 1.08,
          ),
        );
        velocity = math.Point(nx * speed, ny * speed);
        hitCount++;
      }
    }
    if (puck.y < -puckRadius) {
      _point(0);
    } else if (puck.y > height + puckRadius) {
      _point(1);
    }
  }

  void _point(int player) {
    scores[player]++;
    if (scores[player] >= winningScore) {
      winner = player;
      return;
    }
    _serve(player == 0 ? -1 : 1);
  }

  void _serve(int direction) {
    puck = const math.Point(180, 300);
    velocity = math.Point(95.0, 300.0 * direction.toDouble());
  }
}
