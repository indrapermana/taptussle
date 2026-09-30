import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/slither_snakes/slither_challenge_profile.dart';
import 'package:tap_tussle/games/slither_snakes/slither_simulation.dart';

void main() {
  group('SlitherChallengeProfile', () {
    test('maps every shared difficulty to the expected profile', () {
      expect(
        SlitherChallengeProfile.forDifficulty(BotDifficulty.easy),
        same(SlitherChallengeProfile.easy),
      );
      expect(
        SlitherChallengeProfile.forDifficulty(BotDifficulty.normal),
        same(SlitherChallengeProfile.normal),
      );
      expect(
        SlitherChallengeProfile.forDifficulty(BotDifficulty.hard),
        same(SlitherChallengeProfile.hard),
      );
    });

    test('raises AI pressure while reducing food across difficulty', () {
      final easy = SlitherChallengeProfile.easy.config;
      final normal = SlitherChallengeProfile.normal.config;
      final hard = SlitherChallengeProfile.hard.config;

      expect(easy.aiCount, lessThan(normal.aiCount));
      expect(normal.aiCount, lessThan(hard.aiCount));
      expect(easy.foodTarget, greaterThan(normal.foodTarget));
      expect(normal.foodTarget, greaterThan(hard.foodTarget));
      expect(easy.aiBaseSpeed, lessThan(normal.aiBaseSpeed));
      expect(normal.aiBaseSpeed, lessThan(hard.aiBaseSpeed));
      expect(easy.aiMaximumSpeed, lessThan(normal.aiMaximumSpeed));
      expect(normal.aiMaximumSpeed, lessThan(hard.aiMaximumSpeed));
      expect(easy.aiTurnRate, lessThan(normal.aiTurnRate));
      expect(normal.aiTurnRate, lessThan(hard.aiTurnRate));
      expect(easy.aiSpeedPerFood, lessThan(normal.aiSpeedPerFood));
      expect(normal.aiSpeedPerFood, lessThan(hard.aiSpeedPerFood));
    });

    test('keeps player steering and speed progression identical', () {
      final configs = [
        SlitherChallengeProfile.easy.config,
        SlitherChallengeProfile.normal.config,
        SlitherChallengeProfile.hard.config,
      ];

      expect(
        configs.map((config) => config.playerBaseSpeed).toSet(),
        hasLength(1),
      );
      expect(
        configs.map((config) => config.maximumSpeed).toSet(),
        hasLength(1),
      );
      expect(
        configs.map((config) => config.speedPerFood).toSet(),
        hasLength(1),
      );
      expect(
        configs.map((config) => config.playerTurnRate).toSet(),
        hasLength(1),
      );
    });

    test('creates the configured opponent and food population', () {
      for (final profile in [
        SlitherChallengeProfile.easy,
        SlitherChallengeProfile.normal,
        SlitherChallengeProfile.hard,
      ]) {
        final simulation = SlitherSimulation(seed: 33, config: profile.config);

        expect(simulation.opponents, hasLength(profile.config.aiCount));
        expect(simulation.food, hasLength(profile.config.foodTarget));
      }
    });

    test('AI food progression follows its difficulty-specific speed curve', () {
      final speeds = <double>[];
      for (final profile in [
        SlitherChallengeProfile.easy,
        SlitherChallengeProfile.normal,
        SlitherChallengeProfile.hard,
      ]) {
        final simulation = SlitherSimulation(seed: 44, config: profile.config);
        simulation.opponents.first.foodEaten = 8;
        speeds.add(simulation.speedFor(simulation.opponents.first));
      }

      expect(speeds[0], lessThan(speeds[1]));
      expect(speeds[1], lessThan(speeds[2]));
    });
  });
}
