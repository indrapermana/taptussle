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

    test(
      'steering accelerates gradually while movement remains continuous',
      () {
        final simulation = _custom(
          player: _snake(
            id: 0,
            player: true,
            head: const SlitherPoint(250, 250),
          ),
        );
        simulation.steerToward(const SlitherPoint(250, 0));

        simulation.update(SlitherSimulation.fixedStep);

        expect(simulation.player.turnVelocity, closeTo(-72 / 60, 1e-9));
        expect(
          simulation.player.heading,
          closeTo(2 * pi - (72 / 60) / 60, 1e-9),
        );
        expect(simulation.player.head.x, greaterThan(250));
        expect(simulation.player.head.y, lessThan(250));
      },
    );

    test('body samples keep stable spacing through a turn', () {
      final simulation = _custom(
        player: _snake(id: 0, player: true, head: const SlitherPoint(250, 250)),
      );
      simulation.steerToward(const SlitherPoint(250, 0));

      simulation.update(.5);

      final segments = simulation.player.segments;
      expect(segments, hasLength(simulation.player.targetSegmentCount));
      for (var index = 0; index < segments.length - 1; index++) {
        expect(
          segments[index].distanceTo(segments[index + 1]),
          closeTo(simulation.config.segmentSpacing, 1e-7),
        );
      }
    });

    test('direction steering completes a 180 degree turn without orbiting', () {
      const config = SlitherSimulationConfig(
        arenaWidth: 2000,
        arenaHeight: 2000,
        aiCount: 0,
        foodTarget: 0,
      );
      final simulation = SlitherSimulation.custom(
        seed: 2,
        player: _snake(
          id: 0,
          player: true,
          head: const SlitherPoint(1000, 1000),
        ),
        config: config,
      );

      simulation.steerInDirection(pi);
      simulation.update(1.2);

      expect(simulation.player.heading, closeTo(pi, .02));
      expect((simulation.player.head.y - 1000).abs(), lessThan(45));
      expect(simulation.steeringHeading, pi);
      expect(simulation.isGameOver, isFalse);
    });

    for (final tier in SlitherFoodTier.values) {
      test('${tier.name} food applies its exact progression values', () {
        final player = _snake(
          id: 0,
          player: true,
          head: const SlitherPoint(100, 100),
        );
        final simulation = _custom(
          player: player,
          food: [
            SlitherFood(
              id: 4,
              position: const SlitherPoint(103, 100),
              tier: tier,
            ),
          ],
        );
        final initialLength = player.targetSegmentCount;
        final initialSpeed = simulation.speedFor(player);

        simulation.update(SlitherSimulation.fixedStep);

        expect(simulation.score, tier.score);
        expect(player.foodEaten, 1);
        expect(player.foodMass, tier.mass);
        expect(player.targetSegmentCount, initialLength + tier.growthSegments);
        expect(simulation.speedFor(player), greaterThan(initialSpeed));
        expect(simulation.food, isEmpty);
      });
    }

    test('seeded food field contains reproducible size and color variety', () {
      final first = SlitherSimulation(seed: 91);
      final second = SlitherSimulation(seed: 91);

      expect(first.food, second.food);
      expect(first.food.map((item) => item.tier).toSet(), hasLength(3));
      expect(first.food.map((item) => item.colorIndex).toSet().length, 6);
    });

    test('mass grows snake radius up to its configured cap', () {
      final simulation = SlitherSimulation(seed: 12);
      final snake = simulation.player;

      expect(simulation.radiusFor(snake), simulation.config.snakeRadius);
      expect(snake.targetSegmentCount, simulation.config.initialSegments);
      snake.foodMass = 100000;
      expect(simulation.radiusFor(snake), simulation.config.maximumSnakeRadius);
    });

    test(
      'every snake scores food and leaderboard uses mass as tie breaker',
      () {
        final player = _snake(
          id: 0,
          player: true,
          head: const SlitherPoint(450, 450),
        )..score = 12;
        final ai = _snake(
          id: 1,
          player: false,
          head: const SlitherPoint(100, 100),
        );
        final simulation = _custom(
          player: player,
          opponents: [ai],
          food: const [
            SlitherFood(
              id: 7,
              position: SlitherPoint(103, 100),
              tier: SlitherFoodTier.medium,
            ),
          ],
        );

        simulation.update(SlitherSimulation.fixedStep);

        expect(ai.score, SlitherFoodTier.medium.score);
        expect(ai.foodMass, SlitherFoodTier.medium.mass);
        expect(simulation.leader, same(ai));
        expect(simulation.playerRank, 2);
      },
    );

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
        extraSegments: _trailBetween(
          const SlitherPoint(350, 350),
          const SlitherPoint(102, 100),
          142,
        ),
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
        extraSegments: _trailBetween(
          const SlitherPoint(350, 350),
          const SlitherPoint(102, 100),
          142,
        ),
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

    test('AI avoids a nearby wall before pursuing food', () {
      final simulation = _custom(
        player: _snake(id: 0, player: true, head: const SlitherPoint(400, 400)),
        opponents: [
          _snake(
            id: 1,
            player: false,
            head: const SlitherPoint(30, 250),
            heading: pi,
          ),
        ],
        food: const [SlitherFood(id: 1, position: SlitherPoint(10, 250))],
      );

      simulation.update(SlitherSimulation.fixedStep);

      expect(simulation.opponents.first.turnVelocity, isNegative);
    });

    test('AI values a nearby large food opportunity over a small one', () {
      final ai = _snake(
        id: 1,
        player: false,
        head: const SlitherPoint(250, 250),
      );
      final simulation = _custom(
        player: _snake(id: 0, player: true, head: const SlitherPoint(450, 450)),
        opponents: [ai],
        food: const [
          SlitherFood(
            id: 1,
            position: SlitherPoint(280, 220),
            tier: SlitherFoodTier.small,
          ),
          SlitherFood(
            id: 2,
            position: SlitherPoint(290, 280),
            tier: SlitherFoodTier.large,
          ),
        ],
      );

      simulation.update(SlitherSimulation.fixedStep);

      expect(ai.turnVelocity, isPositive);
    });

    test('defeated AI respawns deterministically away from the player', () {
      SlitherSimulation create() {
        const config = SlitherSimulationConfig(
          arenaWidth: 1000,
          arenaHeight: 1000,
          aiCount: 0,
          foodTarget: 0,
          aiRespawnDelay: .1,
        );
        return SlitherSimulation.custom(
          seed: 73,
          player: _snake(
            id: 0,
            player: true,
            head: const SlitherPoint(500, 500),
          ),
          opponents: [
            _snake(
              id: 1,
              player: false,
              head: const SlitherPoint(990, 100),
              heading: 0,
              age: 3,
            ),
          ],
          config: config,
        );
      }

      final first = create();
      final second = create();
      first.update(SlitherSimulation.fixedStep);
      second.update(SlitherSimulation.fixedStep);
      expect(first.opponents.first.alive, isFalse);

      first.update(.11);
      second.update(.11);

      expect(first.opponents.first.alive, isTrue);
      expect(first.opponents.first.age, lessThan(first.config.spawnProtection));
      expect(first.opponents.first.head, second.opponents.first.head);
      expect(
        first.opponents.first.head.distanceTo(first.player.head),
        greaterThan(500),
      );
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

List<SlitherPoint> _trailBetween(
  SlitherPoint start,
  SlitherPoint end,
  int samples,
) => [
  for (var index = 1; index <= samples; index++)
    SlitherPoint(
      start.x + (end.x - start.x) * index / samples,
      start.y + (end.y - start.y) * index / samples,
    ),
];
