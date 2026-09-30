import 'dart:math';

enum SlitherGameOverReason { wall, otherSnake }

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

class SlitherFood {
  const SlitherFood({required this.id, required this.position});

  final int id;
  final SlitherPoint position;

  @override
  bool operator ==(Object other) =>
      other is SlitherFood && id == other.id && position == other.position;

  @override
  int get hashCode => Object.hash(id, position);
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
  int targetSegmentCount;
  double age;
  int foodEaten = 0;
  bool alive = true;

  SlitherPoint get head => segments.first;
}

class SlitherSimulationConfig {
  const SlitherSimulationConfig({
    this.arenaWidth = 2400,
    this.arenaHeight = 1800,
    this.aiCount = 4,
    this.foodTarget = 45,
    this.playerBaseSpeed = 150,
    this.aiBaseSpeed = 142,
    this.maximumSpeed = 220,
    this.speedPerFood = 2.5,
    this.playerTurnRate = 3.2,
    this.aiTurnRate = 2.4,
    this.spawnProtection = 2,
    this.snakeRadius = 12,
    this.foodRadius = 8,
    this.initialSegments = 60,
    this.growthSegmentsPerFood = 4,
    this.foodScore = 10,
    this.defeatedAiBonus = 100,
  }) : assert(arenaWidth > 0),
       assert(arenaHeight > 0),
       assert(aiCount >= 0),
       assert(foodTarget >= 0),
       assert(playerBaseSpeed > 0),
       assert(aiBaseSpeed > 0),
       assert(maximumSpeed >= playerBaseSpeed),
       assert(spawnProtection >= 0),
       assert(initialSegments > 0);

  final double arenaWidth;
  final double arenaHeight;
  final int aiCount;
  final int foodTarget;
  final double playerBaseSpeed;
  final double aiBaseSpeed;
  final double maximumSpeed;
  final double speedPerFood;
  final double playerTurnRate;
  final double aiTurnRate;
  final double spawnProtection;
  final double snakeRadius;
  final double foodRadius;
  final int initialSegments;
  final int growthSegmentsPerFood;
  final int foodScore;
  final int defeatedAiBonus;
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
  List<SlitherSnake> _snakes = [];
  List<SlitherFood> _food = [];
  int _nextFoodId = 0;
  double _accumulator = 0;
  SlitherPoint? _steeringTarget;

  List<SlitherSnake> get snakes => List.unmodifiable(_snakes);
  SlitherSnake get player => _snakes.first;
  List<SlitherSnake> get opponents =>
      List.unmodifiable(_snakes.where((snake) => !snake.isPlayer));
  List<SlitherFood> get food => List.unmodifiable(_food);

  int score = 0;
  int defeatedAi = 0;
  double survivalTime = 0;
  SlitherGameOverReason? gameOverReason;
  bool get isGameOver => gameOverReason != null;

  double speedFor(SlitherSnake snake) => min(
    config.maximumSpeed,
    snake.baseSpeed + snake.foodEaten * config.speedPerFood,
  );

  void steerToward(SlitherPoint? arenaTarget) => _steeringTarget = arenaTarget;

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
    for (final snake in _snakes.where((snake) => snake.alive)) {
      snake.age += fixedStep;
      final target = snake.isPlayer
          ? _steeringTarget
          : _nearestFood(snake.head)?.position;
      if (target != null) {
        final desired = atan2(target.y - snake.head.y, target.x - snake.head.x);
        final turnRate = snake.isPlayer
            ? config.playerTurnRate
            : config.aiTurnRate;
        snake.heading = _turnToward(
          snake.heading,
          desired,
          turnRate * fixedStep,
        );
      }
      final distance = speedFor(snake) * fixedStep;
      final next = SlitherPoint(
        snake.head.x + cos(snake.heading) * distance,
        snake.head.y + sin(snake.heading) * distance,
      );
      snake.segments.insert(0, next);
      while (snake.segments.length > snake.targetSegmentCount) {
        snake.segments.removeLast();
      }
    }

    _resolveCollisions();
    if (isGameOver) return;
    _consumeFood();
    _replenishFood();
  }

  void _resolveCollisions() {
    final deaths = <SlitherSnake, bool>{};
    for (final snake in _snakes.where((snake) => snake.alive)) {
      final outside =
          snake.head.x < config.snakeRadius ||
          snake.head.x > config.arenaWidth - config.snakeRadius ||
          snake.head.y < config.snakeRadius ||
          snake.head.y > config.arenaHeight - config.snakeRadius;
      if (outside) {
        if (snake.isPlayer) {
          gameOverReason = SlitherGameOverReason.wall;
        } else {
          deaths[snake] = false;
        }
        continue;
      }
      if (snake.age < config.spawnProtection) continue;

      for (final other in _snakes.where((candidate) => candidate.alive)) {
        if (identical(snake, other)) continue; // Self-crossing is harmless.
        final hit = other.segments.any(
          (segment) =>
              snake.head.distanceTo(segment) <= config.snakeRadius * 1.7,
        );
        if (!hit) continue;
        if (snake.isPlayer) {
          gameOverReason = SlitherGameOverReason.otherSnake;
        } else {
          deaths[snake] = other.isPlayer;
        }
        break;
      }
    }

    for (final entry in deaths.entries) {
      _defeatAi(entry.key, defeatedByPlayer: entry.value);
    }
  }

  void _defeatAi(SlitherSnake snake, {required bool defeatedByPlayer}) {
    if (!snake.alive) return;
    snake.alive = false;
    for (var index = 0; index < snake.segments.length; index += 5) {
      _food.add(
        SlitherFood(id: _nextFoodId++, position: snake.segments[index]),
      );
    }
    if (defeatedByPlayer) {
      defeatedAi++;
      score += config.defeatedAiBonus;
    }
  }

  void _consumeFood() {
    final consumedIds = <int>{};
    for (final snake in _snakes.where((snake) => snake.alive)) {
      for (final item in _food) {
        if (consumedIds.contains(item.id)) continue;
        if (snake.head.distanceTo(item.position) >
            config.snakeRadius + config.foodRadius) {
          continue;
        }
        consumedIds.add(item.id);
        snake.foodEaten++;
        snake.targetSegmentCount += config.growthSegmentsPerFood;
        if (snake.isPlayer) score += config.foodScore;
        break;
      }
    }
    _food.removeWhere((item) => consumedIds.contains(item.id));
  }

  SlitherFood? _nearestFood(SlitherPoint point) {
    SlitherFood? nearest;
    var distance = double.infinity;
    for (final item in _food) {
      final nextDistance = point.distanceTo(item.position);
      if (nextDistance < distance) {
        nearest = item;
        distance = nextDistance;
      }
    }
    return nearest;
  }

  void _replenishFood() {
    while (_food.length < config.foodTarget) {
      _food.add(
        SlitherFood(id: _nextFoodId++, position: _randomArenaPoint(40)),
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
    final spacing = speed * fixedStep;
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

  static double _turnToward(double current, double target, double maximumTurn) {
    var difference = (target - current + pi) % (2 * pi) - pi;
    difference = difference.clamp(-maximumTurn, maximumTurn);
    var result = (current + difference) % (2 * pi);
    if (result < 0) result += 2 * pi;
    return result;
  }
}
