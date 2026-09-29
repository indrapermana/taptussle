import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/mini_game.dart';

void main() {
  Widget buildPlaceholder(_, _) => const SizedBox.shrink();

  test('existing catalog keeps its two-player bot capabilities', () {
    final existingGames = gameCatalog.where(
      (game) =>
          game.id != 'memory-match' &&
          game.id != 'snakes-and-ladders' &&
          game.id != 'sudoku',
    );
    expect(gameCatalog, hasLength(9));

    for (final game in existingGames) {
      expect(game.supportedPlayerCounts, {PlayerCount.two});
      expect(game.supportsPlayerCount(PlayerCount.two), isTrue);
      expect(game.supportsPlayerCount(PlayerCount.one), isFalse);
      expect(game.supportedModes, {PlayMode.friend, PlayMode.bot});
      expect(game.difficultyType, DifficultyType.bot);
      expect(game.recordDefinition, isNull);
    }
  });

  test('Snakes & Ladders supports fair flexible multiplayer setup', () {
    final game = gameCatalog.singleWhere(
      (game) => game.id == 'snakes-and-ladders',
    );

    expect(game.supportedPlayerCounts, {
      PlayerCount.two,
      PlayerCount.three,
      PlayerCount.four,
    });
    expect(game.supportedModes, {PlayMode.friend, PlayMode.bot});
    expect(game.difficultyType, DifficultyType.none);
    expect(game.recordDefinition, isNull);
    expect(game.matchLabel!(MatchOptions.friend()), 'FIRST TO SQUARE 64');
  });

  test('Memory Match supports solo records plus friend and bot modes', () {
    final game = gameCatalog.singleWhere((game) => game.id == 'memory-match');

    expect(game.supportedPlayerCounts, {PlayerCount.one, PlayerCount.two});
    expect(game.supportedModes, {PlayMode.solo, PlayMode.friend, PlayMode.bot});
    expect(game.difficultyType, DifficultyType.challenge);
    expect(game.recordDefinition!.primaryMetric.id, 'moves');
    expect(
      game.recordDefinition!.primaryMetric.sortOrder,
      RecordSortOrder.lowerIsBetter,
    );
    expect(game.recordDefinition!.tieBreakers.single.id, 'time');
    expect(
      game.recordVariantFor(
        const GamePreferences(difficulty: BotDifficulty.hard),
      ),
      'hard',
    );
  });

  test('Sudoku is a solo puzzle with level-first records', () {
    final game = gameCatalog.singleWhere((game) => game.id == 'sudoku');

    expect(game.supportedPlayerCounts, {PlayerCount.one});
    expect(game.supportedModes, {PlayMode.solo});
    expect(game.difficultyType, DifficultyType.puzzle);
    expect(game.recordDefinition!.metrics.map((metric) => metric.id), [
      'level',
      'unassisted',
      'mistakes',
      'time',
    ]);
    expect(game.recordDefinition!.metrics.map((metric) => metric.sortOrder), [
      RecordSortOrder.higherIsBetter,
      RecordSortOrder.higherIsBetter,
      RecordSortOrder.lowerIsBetter,
      RecordSortOrder.lowerIsBetter,
    ]);
    expect(
      game.difficultyDescription!(BotDifficulty.hard),
      contains('Advanced'),
    );
  });

  test('defaults preserve the original friend-only two-player contract', () {
    final game = MiniGame(
      id: 'fixture',
      title: 'Fixture',
      subtitle: 'Fixture subtitle',
      instructions: 'Fixture instructions',
      icon: Icons.extension,
      build: buildPlaceholder,
    );

    expect(game.supportedPlayerCounts, {PlayerCount.two});
    expect(game.supportedModes, {PlayMode.friend});
    expect(game.difficultyType, DifficultyType.none);
    expect(game.recordDefinition, isNull);
  });

  test('solo puzzle metadata supports ordered record tie-breakers', () {
    final game = MiniGame(
      id: 'level-puzzle',
      title: 'Level Puzzle',
      subtitle: 'Fixture subtitle',
      instructions: 'Fixture instructions',
      icon: Icons.extension,
      build: buildPlaceholder,
      supportedPlayerCounts: const {PlayerCount.one},
      supportedModes: const {PlayMode.solo},
      difficultyType: DifficultyType.puzzle,
      recordDefinition: GameRecordDefinition(
        primaryMetric: const RecordMetricDefinition(
          id: 'level',
          label: 'Level',
          format: RecordMetricFormat.integer,
          sortOrder: RecordSortOrder.higherIsBetter,
        ),
        tieBreakers: const [
          RecordMetricDefinition(
            id: 'moves',
            label: 'Moves',
            format: RecordMetricFormat.integer,
            sortOrder: RecordSortOrder.lowerIsBetter,
          ),
          RecordMetricDefinition(
            id: 'time',
            label: 'Time',
            format: RecordMetricFormat.duration,
            sortOrder: RecordSortOrder.lowerIsBetter,
          ),
        ],
      ),
    );

    expect(game.supportsPlayerCount(PlayerCount.one), isTrue);
    expect(game.supportedModes, {PlayMode.solo});
    expect(game.difficultyType, DifficultyType.puzzle);
    expect(game.recordDefinition!.recordType, 'solo');
    expect(
      game.recordVariantFor(
        const GamePreferences(difficulty: BotDifficulty.hard),
      ),
      'hard',
    );
    expect(game.recordDefinition!.metrics.map((metric) => metric.id), [
      'level',
      'moves',
      'time',
    ]);
    expect(
      game.recordDefinition!.metrics.first.sortOrder,
      RecordSortOrder.higherIsBetter,
    );
    expect(
      () => game.supportedModes.add(PlayMode.friend),
      throwsUnsupportedError,
    );
    expect(
      () => game.supportedPlayerCounts.add(PlayerCount.two),
      throwsUnsupportedError,
    );
    expect(
      () => game.recordDefinition!.tieBreakers.clear(),
      throwsUnsupportedError,
    );
  });
}
