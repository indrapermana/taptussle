import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/lane_dash/lane_dash_model.dart';

void main() {
  test('seeded obstacle courses are fair and lane movement stays bounded', () {
    final a = LaneDashModel(random: Random(4)),
        b = LaneDashModel(random: Random(4));
    for (var player = 0; player < 2; player++) {
      expect(
        a.obstaclesFor(player).map((o) => o.blockedLanes),
        b.obstaclesFor(player).map((o) => o.blockedLanes),
      );
    }
    expect(
      a.obstaclesFor(0).map((o) => o.blockedLanes),
      isNot(a.obstaclesFor(1).map((o) => o.blockedLanes)),
    );
    expect(
      a.obstacleCourses
          .expand((course) => course)
          .every((o) => o.blockedLanes.length < LaneDashModel.laneCount),
      isTrue,
    );
    a.move(0, -9);
    a.move(1, 9);
    expect(a.lanes, [0, 2]);
  });
}
