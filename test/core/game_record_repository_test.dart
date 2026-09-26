import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/core/game_record_repository.dart';
import 'package:tap_tussle/core/mini_game.dart';

final recordDefinition = GameRecordDefinition(
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
      id: 'timeMs',
      label: 'Time',
      format: RecordMetricFormat.duration,
      sortOrder: RecordSortOrder.lowerIsBetter,
    ),
  ],
);

const easyKey = GameRecordKey(
  gameId: 'water-sort',
  recordType: 'solo-level',
  variant: 'easy',
);

GameRecord result(
  int day, {
  required int level,
  required int moves,
  required int timeMs,
  GameRecordKey key = easyKey,
}) => GameRecord(
  key: key,
  completedAt: DateTime(2026, 9, day, 12),
  metrics: {'level': level, 'moves': moves, 'timeMs': timeMs},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'records persist offline and remain separated by complete key',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = GameRecordRepository(preferences);
      const normalKey = GameRecordKey(
        gameId: 'water-sort',
        recordType: 'solo-level',
        variant: 'normal',
      );

      await repository.addRecord(
        definition: recordDefinition,
        record: result(20, level: 4, moves: 18, timeMs: 90000),
      );
      await repository.addRecord(
        definition: recordDefinition,
        record: result(21, level: 3, moves: 12, timeMs: 70000, key: normalKey),
      );

      final restored = GameRecordRepository(preferences);
      expect(restored.recordsFor(easyKey), hasLength(1));
      expect(restored.recordsFor(normalKey), hasLength(1));
      expect(restored.recordsFor(easyKey).single.completedAt.isUtc, isFalse);
      expect(
        () => restored
            .recordsFor(easyKey)
            .add(result(22, level: 5, moves: 10, timeMs: 60000)),
        throwsUnsupportedError,
      );
      expect(
        () => restored.recordsFor(easyKey).single.metrics['level'] = 99,
        throwsUnsupportedError,
      );
    },
  );

  test(
    'ranking follows primary metric then ordered mixed-direction ties',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = GameRecordRepository(
        await SharedPreferences.getInstance(),
      );
      final records = [
        result(21, level: 8, moves: 20, timeMs: 80000),
        result(22, level: 9, moves: 30, timeMs: 90000),
        result(23, level: 9, moves: 25, timeMs: 95000),
        result(24, level: 9, moves: 25, timeMs: 85000),
        result(25, level: 9, moves: 25, timeMs: 85000),
      ];
      for (final record in records) {
        await repository.addRecord(
          definition: recordDefinition,
          record: record,
        );
      }

      final ranked = repository.rankedRecords(
        key: easyKey,
        definition: recordDefinition,
      );
      expect(ranked.map((entry) => entry.record.completedAt.day), [
        24,
        25,
        23,
        22,
        21,
      ]);
      expect(ranked.map((entry) => entry.rank), [1, 1, 3, 4, 5]);
      expect(
        repository.bestRecord(key: easyKey, definition: recordDefinition)!.rank,
        1,
      );
    },
  );

  test(
    'invalid metrics and keys are rejected without changing storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = GameRecordRepository(preferences);
      final invalid = GameRecord(
        key: easyKey,
        completedAt: DateTime(2026, 9, 26),
        metrics: {'level': 2, 'moves': 10},
      );

      await expectLater(
        repository.addRecord(definition: recordDefinition, record: invalid),
        throwsArgumentError,
      );
      expect(repository.recordsFor(easyKey), isEmpty);
      expect(preferences.getString(GameRecordRepository.storageKey), isNull);
    },
  );

  test(
    'malformed stored rows are skipped while valid rows remain readable',
    () async {
      final valid = result(26, level: 6, moves: 15, timeMs: 75000);
      SharedPreferences.setMockInitialValues({
        GameRecordRepository.storageKey: jsonEncode([
          valid.toJson(),
          {'gameId': 'broken'},
          'not a record',
        ]),
      });

      final repository = GameRecordRepository(
        await SharedPreferences.getInstance(),
      );
      expect(repository.recordsFor(easyKey), hasLength(1));
      expect(repository.recordsFor(easyKey).single.metrics['level'], 6);
    },
  );

  test(
    'daily and Monday-Sunday bests roll over from stored timestamps',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = GameRecordRepository(
        await SharedPreferences.getInstance(),
      );
      for (final record in [
        result(20, level: 10, moves: 20, timeMs: 90000), // Sunday.
        result(21, level: 8, moves: 18, timeMs: 80000), // Monday.
        result(23, level: 6, moves: 16, timeMs: 70000), // Wednesday.
      ]) {
        await repository.addRecord(
          definition: recordDefinition,
          record: record,
        );
      }

      final wednesday = repository.bests(
        key: easyKey,
        definition: recordDefinition,
        now: DateTime(2026, 9, 23, 18),
      );
      expect(wednesday.daily!.record.metrics['level'], 6);
      expect(wednesday.weekly!.record.metrics['level'], 8);
      expect(wednesday.overall!.record.metrics['level'], 10);

      final nextMonday = repository.bests(
        key: easyKey,
        definition: recordDefinition,
        now: DateTime(2026, 9, 28, 9),
      );
      expect(nextMonday.daily, isNull);
      expect(nextMonday.weekly, isNull);
      expect(nextMonday.overall!.record.metrics['level'], 10);
    },
  );

  test(
    'bounded history preserves the all-time best and newest attempts per key',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = GameRecordRepository(preferences, maxRecordsPerKey: 3);
      const normalKey = GameRecordKey(
        gameId: 'water-sort',
        recordType: 'solo-level',
        variant: 'normal',
      );

      for (final record in [
        result(20, level: 20, moves: 40, timeMs: 120000),
        result(21, level: 2, moves: 30, timeMs: 100000),
        result(22, level: 3, moves: 20, timeMs: 90000),
        result(23, level: 4, moves: 10, timeMs: 80000),
      ]) {
        await repository.addRecord(
          definition: recordDefinition,
          record: record,
        );
      }
      await repository.addRecord(
        definition: recordDefinition,
        record: result(24, level: 1, moves: 10, timeMs: 60000, key: normalKey),
      );

      expect(
        repository.recordsFor(easyKey).map((record) => record.completedAt.day),
        [20, 22, 23],
      );
      expect(repository.recordsFor(normalKey), hasLength(1));
      expect(
        repository
            .bestRecord(key: easyKey, definition: recordDefinition)!
            .record
            .metrics['level'],
        20,
      );

      final restored = GameRecordRepository(preferences, maxRecordsPerKey: 3);
      expect(restored.recordsFor(easyKey), hasLength(3));
      expect(restored.recordsFor(normalKey), hasLength(1));
    },
  );
}
