import 'dart:math' as math;

import '../../core/match_options.dart';
import 'paddle_duel_model.dart';

/// A local opponent that only moves its own paddle through normal input rules.
/// No timers: all decisions run on the match's simulation clock.
class PaddleDuelBot {
  PaddleDuelBot(this.difficulty, {math.Random? random})
    : _random = random ?? math.Random() {
    reset();
  }

  final BotDifficulty difficulty;
  final math.Random _random;
  double _target = PaddleDuelModel.width / 2;
  double _decisionIn = 0;

  double get reactionSeconds => switch (difficulty) {
    BotDifficulty.easy => .32,
    BotDifficulty.normal => .18,
    BotDifficulty.hard => .09,
  };

  double get maxSpeed => switch (difficulty) {
    BotDifficulty.easy => 150,
    BotDifficulty.normal => 230,
    BotDifficulty.hard => 310,
  };

  double get _aimError => switch (difficulty) {
    BotDifficulty.easy => 65,
    BotDifficulty.normal => 30,
    BotDifficulty.hard => 12,
  };

  double get _lookahead => switch (difficulty) {
    BotDifficulty.easy => 0,
    BotDifficulty.normal => .2,
    BotDifficulty.hard => .65,
  };

  void reset() {
    _target = PaddleDuelModel.width / 2;
    _decisionIn = reactionSeconds;
  }

  void update(PaddleDuelModel model, double dt) {
    if (model.winner != null || dt <= 0 || !dt.isFinite) return;
    final elapsed = math.min(dt, .1);
    if (model.serveRemaining > 0) {
      reset();
    } else {
      _decisionIn -= elapsed;
      if (_decisionIn <= 0) {
        _decisionIn += reactionSeconds;
        // Read the present state only, with bounded extrapolation and error.
        final headingTowardsBot = model.velocityY < 0;
        final face =
            PaddleDuelModel.topY +
            PaddleDuelModel.paddleHeight / 2 +
            PaddleDuelModel.radius;
        final timeToPaddle = headingTowardsBot
            ? math.max(0.0, (face - model.ballY) / model.velocityY)
            : 0.0;
        final futureX =
            model.ballX + model.velocityX * math.min(timeToPaddle, _lookahead);
        final span = PaddleDuelModel.width - 2 * PaddleDuelModel.radius;
        final folded = (futureX - PaddleDuelModel.radius) % (2 * span);
        final reflected =
            PaddleDuelModel.radius +
            (folded <= span ? folded : 2 * span - folded);
        _target = headingTowardsBot
            ? reflected + (_random.nextDouble() * 2 - 1) * _aimError
            : PaddleDuelModel.width / 2;
        _target = _target.clamp(
          PaddleDuelModel.paddleWidth / 2,
          PaddleDuelModel.width - PaddleDuelModel.paddleWidth / 2,
        );
      }
    }
    final movement = (_target - model.paddles[1]).clamp(
      -maxSpeed * elapsed,
      maxSpeed * elapsed,
    );
    model.movePaddle(1, model.paddles[1] + movement);
  }
}
