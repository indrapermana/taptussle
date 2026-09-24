import 'dart:math' as math;

import '../../core/match_options.dart';
import 'air_hockey_model.dart';

/// Supplies legal mallet targets using only the puck state visible now.
class AirHockeyBot {
  AirHockeyBot(this.difficulty, {math.Random? random})
    : _random = random ?? math.Random() {
    reset();
  }

  final BotDifficulty difficulty;
  final math.Random _random;
  double _decisionDelay = 0;

  ({
    double reaction,
    double movementSpeed,
    double aimError,
    double tracking,
    double attackY,
    double mistake,
  })
  get _profile => switch (difficulty) {
    BotDifficulty.easy => (
      reaction: .42,
      movementSpeed: 250.0,
      aimError: 55.0,
      tracking: .25,
      attackY: 155.0,
      mistake: .25,
    ),
    BotDifficulty.normal => (
      reaction: .22,
      movementSpeed: 380.0,
      aimError: 25.0,
      tracking: .55,
      attackY: 195.0,
      mistake: .08,
    ),
    BotDifficulty.hard => (
      reaction: .10,
      movementSpeed: 500.0,
      aimError: 8.0,
      tracking: .85,
      attackY: 235.0,
      mistake: .02,
    ),
  };

  void reset() => _decisionDelay = _profile.reaction;

  void update(AirHockeyModel model, double dt) {
    if (dt <= 0 || model.winner != null) return;
    _decisionDelay -= dt;
    if (_decisionDelay > 0) return;

    final profile = _profile;
    _decisionDelay = profile.reaction * (.85 + _random.nextDouble() * .3);
    final puck = model.puck;
    final velocity = model.velocity;
    final incoming = puck.y < AirHockeyModel.height / 2 && velocity.y < -1;

    var targetX = AirHockeyModel.width / 2;
    var targetY = 145.0;
    if (incoming && _random.nextDouble() >= profile.mistake) {
      final travelTime = math.max(
        0.0,
        (puck.y - profile.attackY) / -velocity.y,
      );
      final predictedX = _reflectX(puck.x + velocity.x * travelTime);
      final returnOffset = velocity.x >= 0 ? -48.0 : 48.0;
      targetX = predictedX + returnOffset + _aimError(profile.aimError);
      targetY = (puck.y + 58).clamp(90.0, profile.attackY);
    } else {
      targetX =
          AirHockeyModel.width / 2 +
          (puck.x - AirHockeyModel.width / 2) * profile.tracking +
          _aimError(profile.aimError * .45);
    }

    final current = model.mallets[1];
    final dx = targetX - current.x;
    final dy = targetY - current.y;
    final distance = math.sqrt(dx * dx + dy * dy);
    final maximumStep = profile.movementSpeed * profile.reaction;
    if (distance > maximumStep && distance > 0) {
      targetX = current.x + dx / distance * maximumStep;
      targetY = current.y + dy / distance * maximumStep;
    }
    model.moveMallet(1, targetX, targetY);
  }

  double _aimError(double range) => (_random.nextDouble() * 2 - 1) * range;

  double _reflectX(double x) {
    final minimum = AirHockeyModel.malletRadius;
    final maximum = AirHockeyModel.width - AirHockeyModel.malletRadius;
    final span = maximum - minimum;
    var reflected = (x - minimum) % (span * 2);
    if (reflected < 0) reflected += span * 2;
    if (reflected > span) reflected = span * 2 - reflected;
    return minimum + reflected;
  }
}
