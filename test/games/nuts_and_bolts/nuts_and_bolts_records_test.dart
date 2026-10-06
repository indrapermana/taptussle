import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/core/game_record_repository.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_records.dart';

void main() {
  test('record windows rank level, then moves, then completion time', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = GameRecordRepository(
      await SharedPreferences.getInstance(),
    );
    const key = GameRecordKey(
      gameId: 'nuts-and-bolts',
      recordType: 'solo',
      variant: 'easy',
    );
    final now = DateTime(2026, 10, 6, 12);
    for (final metrics in [
      {'level': 8, 'moves': 18, 'time': 40000},
      {'level': 9, 'moves': 30, 'time': 50000},
      {'level': 9, 'moves': 28, 'time': 60000},
      {'level': 9, 'moves': 28, 'time': 45000},
    ]) {
      await repository.addRecord(
        definition: nutsAndBoltsRecordDefinition,
        record: GameRecord(key: key, completedAt: now, metrics: metrics),
      );
    }

    final bests = repository.bests(
      key: key,
      definition: nutsAndBoltsRecordDefinition,
      now: now,
    );

    expect(bests.daily?.record.metrics, {
      'level': 9,
      'moves': 28,
      'time': 45000,
    });
    expect(bests.weekly?.record.metrics, bests.daily?.record.metrics);
    expect(bests.overall?.record.metrics, bests.daily?.record.metrics);
  });

  test(
    'record history stays bounded while retaining the strongest runs',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = GameRecordRepository(
        await SharedPreferences.getInstance(),
        maxRecordsPerKey: 3,
      );
      const key = GameRecordKey(
        gameId: 'nuts-and-bolts',
        recordType: 'solo',
        variant: 'hard',
      );
      for (var level = 1; level <= 5; level++) {
        await repository.addRecord(
          definition: nutsAndBoltsRecordDefinition,
          record: GameRecord(
            key: key,
            completedAt: DateTime(2026, 10, level),
            metrics: {'level': level, 'moves': 20, 'time': 50000},
          ),
        );
      }

      expect(repository.recordsFor(key), hasLength(3));
      expect(
        repository
            .rankedRecords(key: key, definition: nutsAndBoltsRecordDefinition)
            .map((entry) => entry.record.metrics['level']),
        [5, 4, 3],
      );
    },
  );
}
