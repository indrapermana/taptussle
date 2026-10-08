import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
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
      expect(
        a.obstaclesFor(player).map((o) => o.kind),
        b.obstaclesFor(player).map((o) => o.kind),
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

  test('seeded courses contain varied static hazards and moving traffic', () {
    final model = LaneDashModel(
      random: Random(12),
      difficulty: BotDifficulty.hard,
    );
    final obstacles = model.obstacleCourses.expand((course) => course).toList();
    final staticKinds = obstacles.where((item) => !item.kind.isTraffic);
    final traffic = obstacles.where((item) => item.kind.isTraffic).toList();

    expect(staticKinds.map((item) => item.kind).toSet().length, greaterThan(2));
    expect(traffic, isNotEmpty);
    expect(
      obstacles.every(
        (item) => item.blockedLanes.length < LaneDashModel.laneCount,
      ),
      isTrue,
    );
    for (final obstacle in traffic) {
      expect(obstacle.positionAt(30), lessThan(obstacle.positionAt(0)));
    }
  });

  test('moving traffic crosses once and applies one slowdown', () {
    final model = LaneDashModel(random: Random(3));
    model.obstacleCourses[0] = const [
      LaneObstacle(
        id: 0,
        distance: 100,
        blockedLanes: {1},
        kind: LaneObstacleKind.car,
      ),
    ];
    model.obstacleCourses[1] = const [];
    model.countdown = 0;

    model.update(2);
    expect(model.collisionCount[0], 1);
    expect(model.slowdown[0], greaterThan(0));

    model.update(.5);
    expect(model.collisionCount[0], 1);
  });

  test(
    'traffic activation preserves readable obstacle ordering and spacing',
    () {
      for (final difficulty in BotDifficulty.values) {
        for (var seed = 0; seed < 50; seed++) {
          final model = LaneDashModel(
            random: Random(seed),
            difficulty: difficulty,
          );
          for (final course in model.obstacleCourses) {
            final encounterTimes = course.map(_baseSpeedEncounterTime).toList();
            for (var index = 1; index < encounterTimes.length; index++) {
              expect(
                encounterTimes[index] - encounterTimes[index - 1],
                greaterThan(.35),
                reason:
                    '$difficulty seed $seed obstacle rows must remain ordered',
              );
            }
          }
        }
      }
    },
  );

  test('moving-obstacle outcomes match at 30 and 60 FPS', () {
    final thirtyFps = LaneDashModel(
      random: Random(27),
      difficulty: BotDifficulty.hard,
    )..countdown = 0;
    final sixtyFps = LaneDashModel(
      random: Random(27),
      difficulty: BotDifficulty.hard,
    )..countdown = 0;

    for (var frame = 0; frame < 30 * 20; frame++) {
      thirtyFps.update(1 / 30);
    }
    for (var frame = 0; frame < 60 * 20; frame++) {
      sixtyFps.update(1 / 60);
    }

    expect(thirtyFps.distance[0], closeTo(sixtyFps.distance[0], .001));
    expect(thirtyFps.distance[1], closeTo(sixtyFps.distance[1], .001));
    expect(thirtyFps.collisionCount, sixtyFps.collisionCount);
    expect(thirtyFps.result, sixtyFps.result);
  });
}

double _baseSpeedEncounterTime(LaneObstacle obstacle) {
  if (!obstacle.kind.isTraffic) {
    return obstacle.distance / LaneDashModel.baseSpeed;
  }
  final activationTime = max(
    0.0,
    (obstacle.distance - LaneDashModel.trafficActivationGap) /
        LaneDashModel.baseSpeed,
  );
  final runnerAtActivation = LaneDashModel.baseSpeed * activationTime;
  final gap = obstacle.distance - runnerAtActivation;
  return activationTime +
      gap / (LaneDashModel.baseSpeed - obstacle.kind.longitudinalSpeed);
}
