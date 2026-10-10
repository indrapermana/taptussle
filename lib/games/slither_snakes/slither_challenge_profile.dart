import '../../core/match_options.dart';
import 'slither_simulation.dart';

/// Difficulty tuning for the solo Slither arena.
///
/// Player movement values deliberately stay identical. Difficulty comes from
/// opponent count, opponent movement pressure, and available food.
class SlitherChallengeProfile {
  const SlitherChallengeProfile._({
    required this.difficulty,
    required this.config,
  });

  final BotDifficulty difficulty;
  final SlitherSimulationConfig config;

  static SlitherChallengeProfile forDifficulty(BotDifficulty difficulty) =>
      switch (difficulty) {
        BotDifficulty.easy => easy,
        BotDifficulty.normal => normal,
        BotDifficulty.hard => hard,
      };

  static const easy = SlitherChallengeProfile._(
    difficulty: BotDifficulty.easy,
    config: SlitherSimulationConfig(
      aiCount: 10,
      foodTarget: 280,
      aiBaseSpeed: 125,
      aiMaximumSpeed: 175,
      aiSpeedPerFood: 1.5,
      aiTurnRate: 1.6,
    ),
  );

  static const normal = SlitherChallengeProfile._(
    difficulty: BotDifficulty.normal,
    config: SlitherSimulationConfig(
      aiCount: 18,
      foodTarget: 220,
      aiBaseSpeed: 142,
      aiMaximumSpeed: 220,
      aiSpeedPerFood: 2.5,
      aiTurnRate: 2.4,
    ),
  );

  static const hard = SlitherChallengeProfile._(
    difficulty: BotDifficulty.hard,
    config: SlitherSimulationConfig(
      aiCount: 26,
      foodTarget: 180,
      aiBaseSpeed: 160,
      aiMaximumSpeed: 245,
      aiSpeedPerFood: 3.25,
      aiTurnRate: 3.4,
    ),
  );
}
