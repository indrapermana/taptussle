import 'dart:math';

import '../../core/match_options.dart';

enum LaneDashResult { playerOne, playerTwo, draw, timeout }

enum LaneObstacleKind {
  cone,
  box,
  barrier,
  barricade,
  rock,
  tires,
  car,
  van,
  truck;

  bool get isTraffic => switch (this) {
    car || van || truck => true,
    _ => false,
  };

  double get longitudinalSpeed => switch (this) {
    car => -18,
    van => -13,
    truck => -9,
    _ => 0,
  };
}

class LaneObstacle {
  const LaneObstacle({
    required this.id,
    required this.distance,
    required this.blockedLanes,
    required this.kind,
  });

  final int id;
  final double distance;
  final Set<int> blockedLanes;
  final LaneObstacleKind kind;

  double positionAt(double elapsed) {
    if (!kind.isTraffic) return distance;
    final activationTime = max(
      0,
      (distance - LaneDashModel.trafficActivationGap) / LaneDashModel.baseSpeed,
    );
    return distance + kind.longitudinalSpeed * max(0, elapsed - activationTime);
  }
}

/// Seedable three-lane race simulation with an independent course per runner.
class LaneDashModel {
  LaneDashModel({Random? random, this.difficulty = BotDifficulty.normal})
    : _random = random ?? Random() {
    obstacleCourses = [_generateObstacles(), _generateObstacles()];
    if (_samePattern(obstacleCourses[0], obstacleCourses[1])) {
      final first = obstacleCourses[1].first;
      obstacleCourses[1] = [
        LaneObstacle(
          id: first.id,
          distance: first.distance,
          blockedLanes: first.blockedLanes
              .map((lane) => (lane + 1) % laneCount)
              .toSet(),
          kind: first.kind,
        ),
        ...obstacleCourses[1].skip(1),
      ];
    }
  }

  static const laneCount = 3;
  static const finishDistance = 1200.0;
  static const trafficActivationGap = 240.0;
  static const maximumDuration = Duration(seconds: 45);
  final BotDifficulty difficulty;
  final Random _random;
  late final List<List<LaneObstacle>> obstacleCourses;
  List<LaneObstacle> obstaclesFor(int player) => obstacleCourses[player];
  double obstaclePosition(LaneObstacle obstacle) =>
      obstacle.positionAt(elapsed);
  double obstacleGap(int player, LaneObstacle obstacle) =>
      obstaclePosition(obstacle) - distance[player];
  final lanes = [1, 1];
  final distance = [0.0, 0.0];
  final slowdown = [0.0, 0.0];
  final collisionCount = [0, 0];
  static const baseSpeed = 54.0;
  final speed = [baseSpeed, baseSpeed];
  double elapsed = 0;
  double countdown = 3;
  LaneDashResult? result;

  void reset() {
    lanes[0] = lanes[1] = 1;
    distance[0] = distance[1] = 0;
    slowdown[0] = slowdown[1] = 0;
    collisionCount[0] = collisionCount[1] = 0;
    elapsed = 0;
    countdown = 3;
    result = null;
  }

  List<LaneObstacle> _generateObstacles() {
    final generated = <LaneObstacle>[];
    var previousOpenLane = -1;
    var twoBackOpenLane = -1;
    final gap = switch (difficulty) {
      BotDifficulty.easy => 190.0,
      BotDifficulty.normal => 145.0,
      BotDifficulty.hard => 110.0,
    };
    final startOffset = 150.0 + _random.nextDouble() * 110.0;
    for (
      var distance = startOffset;
      distance < finishDistance;
      distance += gap
    ) {
      var openLane = _random.nextInt(laneCount);
      if (openLane == previousOpenLane && openLane == twoBackOpenLane) {
        openLane = (openLane + 1 + _random.nextInt(laneCount - 1)) % laneCount;
      }
      twoBackOpenLane = previousOpenLane;
      previousOpenLane = openLane;

      // Hard has more blocked lanes; every row still has a safe lane.
      final blockedLaneCount = switch (difficulty) {
        BotDifficulty.easy => 1,
        BotDifficulty.normal => generated.length % 3 == 2 ? 2 : 1,
        BotDifficulty.hard => 2,
      };
      final blocked = <int>{};
      final candidates = [
        for (var lane = 0; lane < laneCount; lane++)
          if (lane != openLane) lane,
      ]..shuffle(_random);
      for (var index = 0; index < blockedLaneCount; index++) {
        blocked.add(candidates[index]);
      }
      generated.add(
        LaneObstacle(
          id: generated.length,
          distance: distance,
          blockedLanes: Set.unmodifiable(blocked),
          kind: _obstacleKind(generated.length),
        ),
      );
    }
    return List.unmodifiable(generated);
  }

  LaneObstacleKind _obstacleKind(int index) {
    const staticKinds = [
      LaneObstacleKind.cone,
      LaneObstacleKind.box,
      LaneObstacleKind.barrier,
      LaneObstacleKind.barricade,
      LaneObstacleKind.rock,
      LaneObstacleKind.tires,
    ];
    const trafficKinds = [
      LaneObstacleKind.car,
      LaneObstacleKind.van,
      LaneObstacleKind.truck,
    ];
    final trafficFrequency = switch (difficulty) {
      BotDifficulty.easy => 5,
      BotDifficulty.normal => 4,
      BotDifficulty.hard => 3,
    };
    if ((index + 1) % trafficFrequency == 0) {
      return trafficKinds[_random.nextInt(trafficKinds.length)];
    }
    return staticKinds[_random.nextInt(staticKinds.length)];
  }

  bool _samePattern(List<LaneObstacle> first, List<LaneObstacle> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index].distance != second[index].distance ||
          first[index].kind != second[index].kind ||
          first[index].blockedLanes.length !=
              second[index].blockedLanes.length ||
          !first[index].blockedLanes.containsAll(second[index].blockedLanes)) {
        return false;
      }
    }
    return true;
  }

  void move(int player, int direction) {
    if (result != null || player < 0 || player > 1) return;
    lanes[player] = (lanes[player] + direction).clamp(0, laneCount - 1);
  }

  void update(double dt) {
    if (result != null || dt <= 0) {
      return;
    }
    var remaining = dt;
    if (countdown > 0) {
      final countdownStep = min(countdown, remaining);
      countdown -= countdownStep;
      remaining -= countdownStep;
      if (remaining <= 0) return;
    }
    while (remaining > .000001 && result == null) {
      final step = min(remaining, 1 / 120);
      _step(step);
      remaining -= step;
    }
  }

  void _step(double dt) {
    elapsed += dt;
    for (var player = 0; player < 2; player++) {
      final previous = distance[player];
      if (slowdown[player] > 0) {
        slowdown[player] = max(0, slowdown[player] - dt);
      }
      distance[player] +=
          (slowdown[player] > 0 ? speed[player] * .48 : speed[player]) * dt;
      for (final obstacle in obstacleCourses[player]) {
        final previousObstaclePosition = obstacle.positionAt(elapsed - dt);
        final obstaclePosition = obstacle.positionAt(elapsed);
        if (previous < previousObstaclePosition &&
            distance[player] >= obstaclePosition &&
            obstacle.blockedLanes.contains(lanes[player])) {
          slowdown[player] = .9;
          collisionCount[player]++;
        }
      }
    }
    final finished = [
      for (var p = 0; p < 2; p++) distance[p] >= finishDistance,
    ];
    if (finished[0] && finished[1]) {
      result = LaneDashResult.draw;
    } else if (finished[0]) {
      result = LaneDashResult.playerOne;
    } else if (finished[1]) {
      result = LaneDashResult.playerTwo;
    } else if (elapsed >= maximumDuration.inSeconds) {
      result = distance[0] == distance[1]
          ? LaneDashResult.draw
          : distance[0] > distance[1]
          ? LaneDashResult.playerOne
          : LaneDashResult.playerTwo;
    }
  }
}
