import 'dart:math';

import '../../core/match_options.dart';
import 'lane_dash_model.dart';

class LaneDashBot {
  LaneDashBot(this.difficulty, {Random? random}) : _random = random ?? Random();
  final BotDifficulty difficulty;
  final Random _random;
  double _decisionDelay = 0;

  void reset() => _decisionDelay = 0;

  void update(LaneDashModel model, double dt) {
    _decisionDelay -= dt;
    if (_decisionDelay > 0 || model.countdown > 0) return;
    final profile = switch (difficulty) {
      BotDifficulty.easy => (lookahead: 80.0, delay: .9, mistake: .55),
      BotDifficulty.normal => (lookahead: 145.0, delay: .45, mistake: .28),
      BotDifficulty.hard => (lookahead: 230.0, delay: .22, mistake: .1),
    };
    _decisionDelay = profile.delay;
    final upcoming =
        model.obstaclesFor(1).where((item) {
          final gap = model.obstacleGap(1, item);
          return gap > 0 && gap <= profile.lookahead;
        }).toList()..sort(
          (first, second) => model
              .obstacleGap(1, first)
              .compareTo(model.obstacleGap(1, second)),
        );
    final obstacle = upcoming.isEmpty ? null : upcoming.first;
    if (obstacle == null || !obstacle.blockedLanes.contains(model.lanes[1])) {
      return;
    }
    final safe = [
      for (var lane = 0; lane < LaneDashModel.laneCount; lane++)
        if (!obstacle.blockedLanes.contains(lane)) lane,
    ];
    final target = _random.nextDouble() < profile.mistake
        ? model.lanes[1]
        : safe.first;
    model.move(1, target - model.lanes[1]);
  }
}
