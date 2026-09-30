import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/core/game_record_repository.dart';
import 'package:tap_tussle/games/water_sort/water_sort_records.dart';

void main() {
  test('record windows rank level, then moves, then completion time', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = GameRecordRepository(
      await SharedPreferences.getInstance(),
    );
    const key = GameRecordKey(
      gameId: 'water-sort-puzzle',
      recordType: 'solo',
      variant: 'easy',
    );
    final now = DateTime(2026, 9, 30, 12);
    for (final metrics in [
      {'level': 8, 'moves': 18, 'time': 40000},
      {'level': 9, 'moves': 30, 'time': 50000},
      {'level': 9, 'moves': 28, 'time': 60000},
      {'level': 9, 'moves': 28, 'time': 45000},
    ]) {
      await repository.addRecord(
        definition: waterSortRecordDefinition,
        record: GameRecord(key: key, completedAt: now, metrics: metrics),
      );
    }

    final bests = repository.bests(
      key: key,
      definition: waterSortRecordDefinition,
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
}
