import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/game_record_repository.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/core/mini_game.dart';
import 'package:tap_tussle/features/match/match_screen.dart';
import 'package:tap_tussle/games/slither_snakes/slither_records.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog declares solo challenge records separated by difficulty', () {
    final game = gameCatalog.singleWhere(
      (game) => game.id == 'slither-style-snakes',
    );

    expect(game.supportedModes, {PlayMode.solo});
    expect(game.supportedPlayerCounts, {PlayerCount.one});
    expect(game.difficultyType, DifficultyType.challenge);
    expect(game.recordDefinition, same(slitherRecordDefinition));
    expect(
      game.recordVariantFor(
        const GamePreferences(difficulty: BotDifficulty.hard),
      ),
      'hard',
    );
  });

  test(
    'score ranks first and longer survival breaks equal-score ties',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = GameRecordRepository(
        await SharedPreferences.getInstance(),
      );
      const key = GameRecordKey(
        gameId: 'slither-style-snakes',
        recordType: 'solo',
        variant: 'normal',
      );
      for (final record in [
        _record(key, day: 20, score: 90, survivalTime: 90000),
        _record(key, day: 21, score: 100, survivalTime: 30000),
        _record(key, day: 22, score: 100, survivalTime: 60000),
      ]) {
        await repository.addRecord(
          definition: slitherRecordDefinition,
          record: record,
        );
      }

      final ranked = repository.rankedRecords(
        key: key,
        definition: slitherRecordDefinition,
      );
      expect(ranked.map((entry) => entry.record.completedAt.day), [22, 21, 20]);
    },
  );

  test(
    'daily weekly and overall bests use the complete difficulty key',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = GameRecordRepository(
        await SharedPreferences.getInstance(),
      );
      const key = GameRecordKey(
        gameId: 'slither-style-snakes',
        recordType: 'solo',
        variant: 'easy',
      );
      for (final record in [
        _record(key, day: 20, score: 300, survivalTime: 50000),
        _record(key, day: 21, score: 200, survivalTime: 70000),
        _record(key, day: 23, score: 100, survivalTime: 90000),
      ]) {
        await repository.addRecord(
          definition: slitherRecordDefinition,
          record: record,
        );
      }

      final bests = repository.bests(
        key: key,
        definition: slitherRecordDefinition,
        now: DateTime(2026, 9, 23, 18),
      );
      expect(bests.daily!.record.metrics['score'], 100);
      expect(bests.weekly!.record.metrics['score'], 200);
      expect(bests.overall!.record.metrics['score'], 300);
    },
  );

  testWidgets('result compares this run with persisted personal bests', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = GameRecordRepository(
      await SharedPreferences.getInstance(),
    );
    const key = GameRecordKey(
      gameId: 'slither-result-fixture',
      recordType: 'solo',
      variant: 'normal',
    );
    await repository.addRecord(
      definition: slitherRecordDefinition,
      record: _record(key, day: 29, score: 100, survivalTime: 30000),
    );
    MatchSession? session;
    final game = MiniGame(
      id: key.gameId,
      title: 'Slither Result Fixture',
      subtitle: 'Test',
      instructions: 'Survive.',
      icon: Icons.gesture_rounded,
      supportedModes: const {PlayMode.solo},
      supportedPlayerCounts: const {PlayerCount.one},
      difficultyType: DifficultyType.challenge,
      recordDefinition: slitherRecordDefinition,
      build: (value, _) {
        session = value;
        return const SizedBox.expand();
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: MatchScreen(
          game: game,
          options: MatchOptions.solo(),
          startImmediately: true,
          recordRepository: repository,
          recordVariant: key.variant,
        ),
      ),
    );

    session!.reportCompletion(
      scores: const [100],
      details: 'Score 100 • Survived 45.0s',
      recordMetrics: const {'score': 100, 'survivalTime': 45000},
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('record-result-panel')), findsOneWidget);
    expect(find.text('NEW OVERALL BEST'), findsOneWidget);
    expect(find.text('Score 100  •  Survival 45.0s'), findsOneWidget);
    expect(find.text('DAILY'), findsOneWidget);
    expect(find.text('WEEKLY'), findsOneWidget);
    expect(find.text('OVERALL'), findsOneWidget);
    expect(repository.recordsFor(key), hasLength(2));
  });
}

GameRecord _record(
  GameRecordKey key, {
  required int day,
  required int score,
  required int survivalTime,
}) => GameRecord(
  key: key,
  completedAt: DateTime(2026, 9, day, 12),
  metrics: {'score': score, 'survivalTime': survivalTime},
);
