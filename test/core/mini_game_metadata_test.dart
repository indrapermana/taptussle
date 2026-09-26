import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/mini_game.dart';

void main() {
  Widget buildPlaceholder(_, _) => const SizedBox.shrink();

  test('existing catalog keeps its two-player bot capabilities', () {
    expect(gameCatalog, hasLength(5));

    for (final game in gameCatalog) {
      expect(game.supportedPlayerCounts, {PlayerCount.two});
      expect(game.supportsPlayerCount(PlayerCount.two), isTrue);
      expect(game.supportsPlayerCount(PlayerCount.one), isFalse);
      expect(game.supportedModes, {PlayMode.friend, PlayMode.bot});
      expect(game.difficultyType, DifficultyType.bot);
      expect(game.recordDefinition, isNull);
    }
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
