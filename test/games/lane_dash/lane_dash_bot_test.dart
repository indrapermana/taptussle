import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/lane_dash/lane_dash_bot.dart';
import 'package:tap_tussle/games/lane_dash/lane_dash_model.dart';

void main() {
  test('bot lookahead uses the moving obstacle current position', () {
    final model = LaneDashModel(random: Random(1));
    model.obstacleCourses[1] = const [
      LaneObstacle(
        id: 0,
        distance: 300,
        blockedLanes: {1},
        kind: LaneObstacleKind.car,
      ),
    ];
    model.countdown = 0;
    model.elapsed = 6;
    final bot = LaneDashBot(BotDifficulty.hard, random: _NoMistakeRandom());

    bot.update(model, .3);

    expect(model.lanes[1], 0);
  });
}

class _NoMistakeRandom implements Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => .9;

  @override
  int nextInt(int max) => 0;
}
