import 'dart:math';

enum SlitherGameOverReason { wall, otherSnake }

class _SnakeSample {
  const _SnakeSample(this.snake, this.point);

  final SlitherSnake snake;
  final SlitherPoint point;
}

class _SpatialIndex<T> {
  _SpatialIndex({required this.cellSize, required this.positionOf});

  final double cellSize;
  final SlitherPoint Function(T item) positionOf;
  final Map<(int, int), List<T>> _cells = {};

  void rebuild(Iterable<T> items) {
    _cells.clear();
    for (final item in items) {
      final point = positionOf(item);
      (_cells[(_cell(point.x), _cell(point.y))] ??= []).add(item);
    }
  }

  Iterable<T> nearby(SlitherPoint point, double radius) sync* {
    final minimumX = _cell(point.x - radius);
    final maximumX = _cell(point.x + radius);
    final minimumY = _cell(point.y - radius);
    final maximumY = _cell(point.y + radius);
    for (var y = minimumY; y <= maximumY; y++) {
      for (var x = minimumX; x <= maximumX; x++) {
        final bucket = _cells[(x, y)];
        if (bucket != null) yield* bucket;
      }
    }
  }

  int _cell(double coordinate) => (coordinate / cellSize).floor();
}

class SlitherPoint {
  const SlitherPoint(this.x, this.y);

  final double x;
  final double y;

  SlitherPoint operator +(SlitherPoint other) =>
      SlitherPoint(x + other.x, y + other.y);
  SlitherPoint operator -(SlitherPoint other) =>
      SlitherPoint(x - other.x, y - other.y);
  SlitherPoint scaled(double factor) => SlitherPoint(x * factor, y * factor);
  double distanceTo(SlitherPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }

  @override
  bool operator ==(Object other) =>
      other is SlitherPoint && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

enum SlitherFoodTier {
  small(radius: 5, mass: 1, growthSegments: 2, score: 5),
  medium(radius: 8, mass: 2, growthSegments: 4, score: 12),
  large(radius: 12, mass: 4, growthSegments: 7, score: 25);

  const SlitherFoodTier({
    required this.radius,
    required this.mass,
    required this.growthSegments,
    required this.score,
  });

  final double radius;
  final int mass;
  final int growthSegments;
  final int score;
}

class SlitherFood {
  const SlitherFood({
    required this.id,
    required this.position,
    this.tier = SlitherFoodTier.small,
    this.colorIndex = 0,
  });

  final int id;
  final SlitherPoint position;
  final SlitherFoodTier tier;
  final int colorIndex;

  @override
  bool operator ==(Object other) =>
      other is SlitherFood &&
      id == other.id &&
      position == other.position &&
      tier == other.tier &&
      colorIndex == other.colorIndex;

  @override
  int get hashCode => Object.hash(id, position, tier, colorIndex);
}

class SlitherSnake {
  SlitherSnake({
    required this.id,
    required this.isPlayer,
    required this.heading,
    required this.baseSpeed,
    required List<SlitherPoint> segments,
    this.targetSegmentCount = 60,
    this.age = 0,
    this.turnVelocity = 0,
    this.respawnRemaining = 0,
    this.score = 0,
  }) : segments = List.of(segments) {
    if (this.segments.isEmpty) {
      throw ArgumentError.value(segments, 'segments', 'Cannot be empty');
    }
    if (targetSegmentCount < this.segments.length) {
      targetSegmentCount = this.segments.length;
    }
  }

  final int id;
  final bool isPlayer;
  final double baseSpeed;
  final List<SlitherPoint> segments;
  double heading;
  double turnVelocity;
  int targetSegmentCount;
  double age;
  int foodEaten = 0;
  int foodMass = 0;
  int score;
  double respawnRemaining;
  bool alive = true;

  SlitherPoint get head => segments.first;
}

class SlitherSimulationConfig {
  const SlitherSimulationConfig({
    this.arenaWidth = 6000,
    this.arenaHeight = 4200,
    this.aiCount = 4,
    this.foodTarget = 220,
    this.playerBaseSpeed = 150,
    this.aiBaseSpeed = 142,
    this.maximumSpeed = 220,
    this.speedPerFood = 2.5,
    this.aiMaximumSpeed = 220,
    this.aiSpeedPerFood = 2.5,
    this.playerTurnRate = 8.5,
    this.aiTurnRate = 2.4,
    this.playerTurnAcceleration = 72,
    this.playerMinimumTurnRadius = 18,
    this.aiTurnAcceleration = 14,
    this.segmentSpacing = 2.5,
    this.spawnProtection = 2,
    this.snakeRadius = 8,
    this.maximumSnakeRadius = 22,
    this.radiusGrowthPerSqrtMass = 1.15,
    this.initialSegments = 36,
    this.defeatedAiBonus = 100,
    this.aiAvoidanceDistance = 115,
    this.aiWallAvoidanceDistance = 150,
    this.aiRespawnDelay = 3,
    this.aiRespawnDistanceFromPlayer = 1200,
  }) : assert(arenaWidth > 0),
       assert(arenaHeight > 0),
       assert(aiCount >= 0),
       assert(foodTarget >= 0),
       assert(playerBaseSpeed > 0),
       assert(aiBaseSpeed > 0),
       assert(maximumSpeed >= playerBaseSpeed),
       assert(aiMaximumSpeed >= aiBaseSpeed),
       assert(speedPerFood >= 0),
       assert(aiSpeedPerFood >= 0),
       assert(playerTurnRate > 0),
       assert(aiTurnRate > 0),
       assert(playerTurnAcceleration > 0),
       assert(playerMinimumTurnRadius > 0),
       assert(aiTurnAcceleration > 0),
       assert(segmentSpacing > 0),
       assert(spawnProtection >= 0),
       assert(snakeRadius > 0),
       assert(maximumSnakeRadius >= snakeRadius),
       assert(radiusGrowthPerSqrtMass >= 0),
       assert(initialSegments > 0),
       assert(aiAvoidanceDistance > 0),
       assert(aiWallAvoidanceDistance > 0),
       assert(aiRespawnDelay >= 0),
       assert(aiRespawnDistanceFromPlayer >= 0);

  final double arenaWidth;
  final double arenaHeight;
  final int aiCount;
  final int foodTarget;
  final double playerBaseSpeed;
  final double aiBaseSpeed;
  final double maximumSpeed;
  final double speedPerFood;
  final double aiMaximumSpeed;
  final double aiSpeedPerFood;
  final double playerTurnRate;
  final double aiTurnRate;
  final double playerTurnAcceleration;
  final double playerMinimumTurnRadius;
  final double aiTurnAcceleration;
  final double segmentSpacing;
  final double spawnProtection;
  final double snakeRadius;
  final double maximumSnakeRadius;
  final double radiusGrowthPerSqrtMass;
  final int initialSegments;
  final int defeatedAiBonus;
  final double aiAvoidanceDistance;
  final double aiWallAvoidanceDistance;
  final double aiRespawnDelay;
  final double aiRespawnDistanceFromPlayer;
}

/// Seeded, fixed-step rules simulation for Slither-style Snakes.
///
/// Rendering and input coordinate conversion live outside this class. The
/// player's steering target is expressed directly in arena coordinates.
class SlitherSimulation {
  SlitherSimulation({
    required int seed,
    this.config = const SlitherSimulationConfig(),
  }) : _random = Random(seed) {
    _createInitialSnakes();
    _replenishFood();
  }

  SlitherSimulation.custom({
    required int seed,
    required SlitherSnake player,
    List<SlitherSnake> opponents = const [],
    List<SlitherFood> food = const [],
    this.config = const SlitherSimulationConfig(aiCount: 0, foodTarget: 0),
  }) : _random = Random(seed),
       _snakes = [player, ...opponents],
       _food = List.of(food),
       _nextFoodId = food.fold(0, (next, item) => max(next, item.id + 1)) {
    if (!player.isPlayer || opponents.any((snake) => snake.isPlayer)) {
      throw ArgumentError('Exactly the first snake must be the player');
    }
  }

  static const double fixedStep = 1 / 60;

  final SlitherSimulationConfig config;
  final Random _random;
  late final _foodIndex = _SpatialIndex<SlitherFood>(
    cellSize: 180,
    positionOf: (item) => item.position,
  );
  late final _bodyIndex = _SpatialIndex<_SnakeSample>(
    cellSize: 140,
    positionOf: (sample) => sample.point,
  );
  List<SlitherSnake> _snakes = [];
  List<SlitherFood> _food = [];
  int _nextFoodId = 0;
  double _accumulator = 0;
  SlitherPoint? _steeringTarget;
  double? _steeringHeading;
  SlitherPoint? get steeringTarget => _steeringTarget;
  double? get steeringHeading => _steeringHeading;

  List<SlitherSnake> get snakes => List.unmodifiable(_snakes);
  SlitherSnake get player => _snakes.first;
  List<SlitherSnake> get opponents =>
      List.unmodifiable(_snakes.where((snake) => !snake.isPlayer));
  List<SlitherFood> get food => List.unmodifiable(_food);

  int defeatedAi = 0;
  double survivalTime = 0;
  SlitherGameOverReason? gameOverReason;
  bool get isGameOver => gameOverReason != null;
  int get score => player.score;

  double radiusFor(SlitherSnake snake) => min(
    config.maximumSnakeRadius,
    config.snakeRadius + sqrt(snake.foodMass) * config.radiusGrowthPerSqrtMass,
  );

  List<SlitherSnake> get leaderboard {
    final ranked = List<SlitherSnake>.of(_snakes);
    ranked.sort((first, second) {
      final scoreOrder = second.score.compareTo(first.score);
      if (scoreOrder != 0) return scoreOrder;
      final massOrder = second.foodMass.compareTo(first.foodMass);
      if (massOrder != 0) return massOrder;
      return first.id.compareTo(second.id);
    });
    return List.unmodifiable(ranked);
  }

  int get playerRank => leaderboard.indexOf(player) + 1;
  SlitherSnake get leader => leaderboard.first;

  double speedFor(SlitherSnake snake) {
    final maximumSpeed = snake.isPlayer
        ? config.maximumSpeed
        : config.aiMaximumSpeed;
    final speedPerFood = snake.isPlayer
        ? config.speedPerFood
        : config.aiSpeedPerFood;
    return min(maximumSpeed, snake.baseSpeed + snake.foodMass * speedPerFood);
  }

  void steerToward(SlitherPoint? arenaTarget) {
    _steeringTarget = arenaTarget;
    _steeringHeading = null;
  }

  void steerInDirection(double? heading) {
    if (heading == null) {
      _steeringHeading = null;
      _steeringTarget = null;
      return;
    }
    _steeringHeading = heading % (2 * pi);
    _steeringTarget = SlitherPoint(
      player.head.x + cos(heading) * 1000,
      player.head.y + sin(heading) * 1000,
    );
  }

  void update(double deltaSeconds) {
    if (isGameOver || deltaSeconds <= 0) return;
    _accumulator += deltaSeconds;
    while (_accumulator + 1e-12 >= fixedStep && !isGameOver) {
      _accumulator -= fixedStep;
      _step();
    }
  }

  void _step() {
    survivalTime += fixedStep;
    _updateRespawns();
    _rebuildSpatialIndexes();
    for (final snake in _snakes.where((snake) => snake.alive)) {
      snake.age += fixedStep;
      final target = snake.isPlayer ? _steeringTarget : _aiTarget(snake);
      final desired = snake.isPlayer && _steeringHeading != null
          ? _steeringHeading
          : target == null
          ? null
          : atan2(target.y - snake.head.y, target.x - snake.head.x);
      if (desired != null) {
        final turnRate = snake.isPlayer
            ? max(
                config.playerTurnRate,
                speedFor(snake) / config.playerMinimumTurnRadius,
              )
            : config.aiTurnRate;
        final acceleration = snake.isPlayer
            ? config.playerTurnAcceleration
            : config.aiTurnAcceleration;
        _steerSnake(
          snake,
          desired: desired,
          maximumTurnRate: turnRate,
          acceleration: acceleration,
        );
      } else {
        snake.turnVelocity = _approach(
          snake.turnVelocity,
          0,
          (snake.isPlayer
                  ? config.playerTurnAcceleration
                  : config.aiTurnAcceleration) *
              fixedStep,
        );
      }
      final distance = speedFor(snake) * fixedStep;
      final next = SlitherPoint(
        snake.head.x + cos(snake.heading) * distance,
        snake.head.y + sin(snake.heading) * distance,
      );
      _advanceBody(snake, next);
    }

    _rebuildBodyIndex();
    _resolveCollisions();
    if (isGameOver) return;
    _consumeFood();
    _replenishFood();
  }

  void _resolveCollisions() {
    final deaths = <SlitherSnake, SlitherSnake?>{};
    for (final snake in _snakes.where((snake) => snake.alive)) {
      final snakeRadius = radiusFor(snake);
      final outside =
          snake.head.x < snakeRadius ||
          snake.head.x > config.arenaWidth - snakeRadius ||
          snake.head.y < snakeRadius ||
          snake.head.y > config.arenaHeight - snakeRadius;
      if (outside) {
        if (snake.isPlayer) {
          gameOverReason = SlitherGameOverReason.wall;
        } else {
          deaths[snake] = null;
        }
        continue;
      }
      if (snake.age < config.spawnProtection) continue;

      final nearbySamples = _bodyIndex.nearby(
        snake.head,
        snakeRadius + config.maximumSnakeRadius * 1.05,
      );
      for (final sample in nearbySamples) {
        final other = sample.snake;
        if (identical(snake, other)) continue;
        if (snake.head.distanceTo(sample.point) >
            (snakeRadius + radiusFor(other)) * 1.05) {
          continue;
        }
        if (snake.isPlayer) {
          gameOverReason = SlitherGameOverReason.otherSnake;
        } else {
          deaths[snake] = other;
        }
        break;
      }
    }

    for (final entry in deaths.entries) {
      _defeatAi(entry.key, defeatedBy: entry.value);
    }
  }

  void _defeatAi(SlitherSnake snake, {required SlitherSnake? defeatedBy}) {
    if (!snake.alive) return;
    snake.alive = false;
    snake.respawnRemaining = config.aiRespawnDelay;
    for (var index = 0; index < snake.segments.length; index += 5) {
      final id = _nextFoodId++;
      _food.add(
        SlitherFood(
          id: id,
          position: snake.segments[index],
          tier: index % 15 == 0
              ? SlitherFoodTier.medium
              : SlitherFoodTier.small,
          colorIndex: id % 6,
        ),
      );
    }
    if (defeatedBy != null) {
      defeatedBy.score += config.defeatedAiBonus;
      if (defeatedBy.isPlayer) defeatedAi++;
    }
  }

  void _consumeFood() {
    final consumedIds = <int>{};
    for (final snake in _snakes.where((snake) => snake.alive)) {
      final collectionRadius = radiusFor(snake) + SlitherFoodTier.large.radius;
      for (final item in _foodIndex.nearby(snake.head, collectionRadius)) {
        if (consumedIds.contains(item.id)) continue;
        if (snake.head.distanceTo(item.position) >
            radiusFor(snake) + item.tier.radius) {
          continue;
        }
        consumedIds.add(item.id);
        snake.foodEaten++;
        snake.foodMass += item.tier.mass;
        snake.targetSegmentCount += item.tier.growthSegments;
        snake.score += item.tier.score;
        break;
      }
    }
    _food.removeWhere((item) => consumedIds.contains(item.id));
  }

  SlitherPoint _aiTarget(SlitherSnake snake) {
    var avoidanceX = 0.0;
    var avoidanceY = 0.0;
    final head = snake.head;
    final wallDistance = config.aiWallAvoidanceDistance;
    if (head.x < wallDistance) {
      avoidanceX += (wallDistance - head.x) / wallDistance;
    }
    if (head.x > config.arenaWidth - wallDistance) {
      avoidanceX -=
          (head.x - (config.arenaWidth - wallDistance)) / wallDistance;
    }
    if (head.y < wallDistance) {
      avoidanceY += (wallDistance - head.y) / wallDistance;
    }
    if (head.y > config.arenaHeight - wallDistance) {
      avoidanceY -=
          (head.y - (config.arenaHeight - wallDistance)) / wallDistance;
    }

    for (final sample in _bodyIndex.nearby(head, config.aiAvoidanceDistance)) {
      if (identical(snake, sample.snake)) continue;
      final dx = head.x - sample.point.x;
      final dy = head.y - sample.point.y;
      final distanceSquared = dx * dx + dy * dy;
      final limitSquared =
          config.aiAvoidanceDistance * config.aiAvoidanceDistance;
      if (distanceSquared < 1e-6 || distanceSquared >= limitSquared) continue;
      final distance = sqrt(distanceSquared);
      final strength = 1 - distance / config.aiAvoidanceDistance;
      avoidanceX += dx / distance * strength * 1.8;
      avoidanceY += dy / distance * strength * 1.8;
    }

    if (avoidanceX.abs() + avoidanceY.abs() > .08) {
      return SlitherPoint(head.x + avoidanceX * 240, head.y + avoidanceY * 240);
    }

    SlitherFood? bestFood;
    var bestValue = double.infinity;
    final nearbyFood = _foodIndex
        .nearby(head, 620)
        .where((item) => head.distanceTo(item.position) <= 620)
        .toList();
    final candidates = nearbyFood.isEmpty ? _food : nearbyFood;
    for (final item in candidates) {
      final weightedDistance =
          head.distanceTo(item.position) / (1 + item.tier.mass * .65);
      if (weightedDistance < bestValue) {
        bestFood = item;
        bestValue = weightedDistance;
      }
    }
    if (bestFood != null) return bestFood.position;

    final orbit = survivalTime * .35 + snake.id * 1.7;
    return SlitherPoint(
      config.arenaWidth / 2 + cos(orbit) * 220,
      config.arenaHeight / 2 + sin(orbit) * 220,
    );
  }

  void _rebuildSpatialIndexes() {
    _foodIndex.rebuild(_food);
    _rebuildBodyIndex();
  }

  void _rebuildBodyIndex() {
    _bodyIndex.rebuild(
      _snakes
          .where((snake) => snake.alive)
          .expand(
            (snake) =>
                snake.segments.map((point) => _SnakeSample(snake, point)),
          ),
    );
  }

  void _updateRespawns() {
    for (final snake in _snakes.where(
      (candidate) => !candidate.isPlayer && !candidate.alive,
    )) {
      snake.respawnRemaining -= fixedStep;
      if (snake.respawnRemaining > 1e-9) continue;
      _respawnAi(snake);
    }
  }

  void _respawnAi(SlitherSnake snake) {
    final head = _respawnPoint();
    final heading = _random.nextDouble() * 2 * pi;
    snake
      ..heading = heading
      ..turnVelocity = 0
      ..targetSegmentCount = config.initialSegments
      ..age = 0
      ..foodEaten = 0
      ..foodMass = 0
      ..respawnRemaining = 0
      ..alive = true;
    snake.segments
      ..clear()
      ..addAll([
        for (var index = 0; index < config.initialSegments; index++)
          SlitherPoint(
            head.x - cos(heading) * config.segmentSpacing * index,
            head.y - sin(heading) * config.segmentSpacing * index,
          ),
      ]);
  }

  SlitherPoint _respawnPoint() {
    final diagonal = sqrt(
      config.arenaWidth * config.arenaWidth +
          config.arenaHeight * config.arenaHeight,
    );
    final minimumDistance = min(
      config.aiRespawnDistanceFromPlayer,
      diagonal * .42,
    );
    SlitherPoint? best;
    var bestDistance = -1.0;
    for (var attempt = 0; attempt < 24; attempt++) {
      final candidate = _randomArenaPoint(
        max(40, config.snakeRadius + config.segmentSpacing * 2),
      );
      final distance = candidate.distanceTo(player.head);
      if (distance > bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
      if (distance >= minimumDistance) return candidate;
    }
    return best!;
  }

  void _replenishFood() {
    while (_food.length < config.foodTarget) {
      final tierRoll = _random.nextDouble();
      final tier = tierRoll < .6
          ? SlitherFoodTier.small
          : tierRoll < .88
          ? SlitherFoodTier.medium
          : SlitherFoodTier.large;
      _food.add(
        SlitherFood(
          id: _nextFoodId++,
          position: _randomArenaPoint(40),
          tier: tier,
          colorIndex: _random.nextInt(6),
        ),
      );
    }
  }

  void _createInitialSnakes() {
    final center = SlitherPoint(config.arenaWidth / 2, config.arenaHeight / 2);
    _snakes.add(
      _snakeAt(
        id: 0,
        isPlayer: true,
        head: center,
        heading: 0,
        speed: config.playerBaseSpeed,
      ),
    );
    for (var index = 0; index < config.aiCount; index++) {
      final angle = index * 2 * pi / max(1, config.aiCount);
      final radius = min(config.arenaWidth, config.arenaHeight) * .32;
      _snakes.add(
        _snakeAt(
          id: index + 1,
          isPlayer: false,
          head: SlitherPoint(
            center.x + cos(angle) * radius,
            center.y + sin(angle) * radius,
          ),
          heading: _random.nextDouble() * 2 * pi,
          speed: config.aiBaseSpeed,
        ),
      );
    }
  }

  SlitherSnake _snakeAt({
    required int id,
    required bool isPlayer,
    required SlitherPoint head,
    required double heading,
    required double speed,
  }) {
    final spacing = config.segmentSpacing;
    return SlitherSnake(
      id: id,
      isPlayer: isPlayer,
      heading: heading,
      baseSpeed: speed,
      targetSegmentCount: config.initialSegments,
      segments: [
        for (var index = 0; index < config.initialSegments; index++)
          SlitherPoint(
            head.x - cos(heading) * spacing * index,
            head.y - sin(heading) * spacing * index,
          ),
      ],
    );
  }

  SlitherPoint _randomArenaPoint(double margin) => SlitherPoint(
    margin + _random.nextDouble() * (config.arenaWidth - margin * 2),
    margin + _random.nextDouble() * (config.arenaHeight - margin * 2),
  );

  void _steerSnake(
    SlitherSnake snake, {
    required double desired,
    required double maximumTurnRate,
    required double acceleration,
  }) {
    final difference = _angleDifference(snake.heading, desired);
    final desiredVelocity = (difference / fixedStep).clamp(
      -maximumTurnRate,
      maximumTurnRate,
    );
    snake.turnVelocity = _approach(
      snake.turnVelocity,
      desiredVelocity,
      acceleration * fixedStep,
    );
    var turn = snake.turnVelocity * fixedStep;
    if (turn.abs() > difference.abs()) {
      turn = difference;
      snake.turnVelocity = 0;
    }
    var result = (snake.heading + turn) % (2 * pi);
    if (result < 0) result += 2 * pi;
    snake.heading = result;
  }

  void _advanceBody(SlitherSnake snake, SlitherPoint nextHead) {
    final trail = <SlitherPoint>[nextHead, ...snake.segments];
    final resampled = <SlitherPoint>[nextHead];
    var trailIndex = 1;
    var cursor = nextHead;
    var remaining = config.segmentSpacing;

    while (resampled.length < snake.targetSegmentCount &&
        trailIndex < trail.length) {
      final endpoint = trail[trailIndex];
      final distance = cursor.distanceTo(endpoint);
      if (distance < 1e-9) {
        cursor = endpoint;
        trailIndex++;
        continue;
      }
      if (distance + 1e-9 >= remaining) {
        final ratio = remaining / distance;
        cursor = SlitherPoint(
          cursor.x + (endpoint.x - cursor.x) * ratio,
          cursor.y + (endpoint.y - cursor.y) * ratio,
        );
        resampled.add(cursor);
        remaining = config.segmentSpacing;
      } else {
        remaining -= distance;
        cursor = endpoint;
        trailIndex++;
      }
    }

    final tail = trail.last;
    while (resampled.length < snake.targetSegmentCount) {
      resampled.add(tail);
    }
    snake.segments
      ..clear()
      ..addAll(resampled);
  }

  static double _angleDifference(double current, double target) =>
      (target - current + pi) % (2 * pi) - pi;

  static double _approach(double current, double target, double maximumChange) {
    if (current < target) return min(current + maximumChange, target);
    if (current > target) return max(current - maximumChange, target);
    return target;
  }
}
