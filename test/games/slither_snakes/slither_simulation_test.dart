import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/slither_snakes/slither_simulation.dart';

void main() {
  group('SlitherSimulation', () {
    test('seeded spawning is reproducible and inside the arena', () {
      final first = SlitherSimulation(seed: 42);
      final second = SlitherSimulation(seed: 42);

      expect(first.food, second.food);
      expect(
        first.snakes.map((snake) => (snake.head, snake.heading)),
        second.snakes.map((snake) => (snake.head, snake.heading)),
      );
      expect(first.opponents, hasLength(first.config.aiCount));
      expect(first.food, hasLength(first.config.foodTarget));
      expect(
        first.food.every(
          (item) =>
              item.position.x > 0 &&
              item.position.x < first.config.arenaWidth &&
              item.position.y > 0 &&
              item.position.y < first.config.arenaHeight,
        ),
        isTrue,
      );
    });

    test('fixed-step updates are independent of caller frame chunks', () {
      final whole = SlitherSimulation(seed: 7);
      final chunks = SlitherSimulation(seed: 7);
      const target = SlitherPoint(1200, 200);
      whole.steerToward(target);
      chunks.steerToward(target);

      whole.update(1);
      for (var frame = 0; frame < 60; frame++) {
        chunks.update(1 / 60);
      }

      expect(whole.player.head, chunks.player.head);
      expect(whole.player.heading, chunks.player.heading);
      expect(whole.survivalTime, chunks.survivalTime);
      expect(whole.food, chunks.food);
    });

    test('steering turns gradually while movement remains continuous', () {
      final simulation = _custom(
        player: _snake(id: 0, player: true, head: const SlitherPoint(250, 250)),
      );
      simulation.steerToward(const SlitherPoint(250, 0));

      simulation.update(SlitherSimulation.fixedStep);

      expect(simulation.player.heading, closeTo(2 * pi - 3.2 / 60, 1e-9));
      expect(simulation.player.head.x, greaterThan(250));
      expect(simulation.player.head.y, lessThan(250));
    });

    test('food increases score, length target, and progression speed', () {
      final player = _snake(
        id: 0,
        player: true,
        head: const SlitherPoint(100, 100),
      );
      final simulation = _custom(
        player: player,
        food: const [SlitherFood(id: 4, position: SlitherPoint(103, 100))],
      );
      final initialLength = player.targetSegmentCount;
      final initialSpeed = simulation.speedFor(player);

      simulation.update(SlitherSimulation.fixedStep);

      expect(simulation.score, simulation.config.foodScore);
      expect(player.foodEaten, 1);
      expect(
        player.targetSegmentCount,
        initialLength + simulation.config.growthSegmentsPerFood,
      );
      expect(simulation.speedFor(player), greaterThan(initialSpeed));
      expect(simulation.food, isEmpty);
    });

    test('hitting the arena wall ends and freezes the run', () {
      final simulation = _custom(
        player: _snake(
          id: 0,
          player: true,
          head: const SlitherPoint(480, 250),
          age: 3,
        ),
      );

      simulation.update(1);
      final stoppedAt = simulation.player.head;
      final survivalTime = simulation.survivalTime;

      expect(simulation.gameOverReason, SlitherGameOverReason.wall);
      simulation.update(1);
      expect(simulation.player.head, stoppedAt);
      expect(simulation.survivalTime, survivalTime);
    });

    test('another snake body ends the run but self-crossing is harmless', () {
      final player = _snake(
        id: 0,
        player: true,
        head: const SlitherPoint(100, 100),
        age: 3,
        extraSegments: const [
          SlitherPoint(102, 100),
          SlitherPoint(102, 100),
          SlitherPoint(102, 100),
          SlitherPoint(102, 100),
        ],
      );
      final safe = _custom(player: player);
      safe.update(SlitherSimulation.fixedStep);
      expect(safe.isGameOver, isFalse);

      final opponent = _snake(
        id: 1,
        player: false,
        head: const SlitherPoint(350, 350),
        age: 3,
        extraSegments: const [
          SlitherPoint(102, 100),
          SlitherPoint(102, 100),
          SlitherPoint(102, 100),
          SlitherPoint(102, 100),
        ],
      );
      final collision = _custom(
        player: _snake(
          id: 0,
          player: true,
          head: const SlitherPoint(100, 100),
          age: 3,
        ),
        opponents: [opponent],
      );
      collision.update(SlitherSimulation.fixedStep);
      expect(collision.gameOverReason, SlitherGameOverReason.otherSnake);
    });

    test('defeated AI becomes food and awards a player-body bonus', () {
      final player = _snake(
        id: 0,
        player: true,
        head: const SlitherPoint(350, 350),
        age: 3,
        extraSegments: const [
          SlitherPoint(102, 100),
          SlitherPoint(102, 100),
          SlitherPoint(102, 100),
          SlitherPoint(102, 100),
        ],
      );
      final ai = _snake(
        id: 1,
        player: false,
        head: const SlitherPoint(100, 100),
        age: 3,
      );
      final simulation = _custom(player: player, opponents: [ai]);

      simulation.update(SlitherSimulation.fixedStep);

      expect(ai.alive, isFalse);
      expect(simulation.defeatedAi, 1);
      expect(simulation.score, simulation.config.defeatedAiBonus);
      expect(simulation.food, isNotEmpty);
      expect(simulation.isGameOver, isFalse);
    });

    test('spawn protection temporarily suppresses body collisions', () {
      final player = _snake(
        id: 0,
        player: true,
        head: const SlitherPoint(350, 350),
        age: 3,
        extraSegments: const [
          SlitherPoint(102, 100),
          SlitherPoint(102, 100),
          SlitherPoint(102, 100),
          SlitherPoint(102, 100),
        ],
      );
      final protectedAi = _snake(
        id: 1,
        player: false,
        head: const SlitherPoint(100, 100),
      );
      final simulation = _custom(player: player, opponents: [protectedAi]);

      simulation.update(SlitherSimulation.fixedStep);

      expect(protectedAi.alive, isTrue);
      expect(simulation.defeatedAi, 0);
    });
  });
}

SlitherSimulation _custom({
  required SlitherSnake player,
  List<SlitherSnake> opponents = const [],
  List<SlitherFood> food = const [],
}) => SlitherSimulation.custom(
  seed: 1,
  player: player,
  opponents: opponents,
  food: food,
  config: const SlitherSimulationConfig(
    arenaWidth: 500,
    arenaHeight: 500,
    aiCount: 0,
    foodTarget: 0,
    initialSegments: 5,
  ),
);

SlitherSnake _snake({
  required int id,
  required bool player,
  required SlitherPoint head,
  double heading = 0,
  double age = 0,
  List<SlitherPoint> extraSegments = const [],
}) => SlitherSnake(
  id: id,
  isPlayer: player,
  heading: heading,
  baseSpeed: player ? 150 : 142,
  age: age,
  targetSegmentCount: max(5, 1 + extraSegments.length),
  segments: [head, ...extraSegments],
);
