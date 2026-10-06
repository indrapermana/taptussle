import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/core/game_record_repository.dart';
import 'package:tap_tussle/games/solitaire/solitaire_records.dart';

void main() {
  test('record windows rank fastest wins then fewest moves', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = GameRecordRepository(
      await SharedPreferences.getInstance(),
    );
    const key = GameRecordKey(
      gameId: 'solitaire',
      recordType: 'win',
      variant: 'easy',
    );
    final now = DateTime(2026, 10, 6, 12);
    for (final metrics in [
      {'time': 300000, 'moves': 100},
      {'time': 240000, 'moves': 130},
      {'time': 240000, 'moves': 110},
    ]) {
      await repository.addRecord(
        definition: solitaireRecordDefinition,
        record: GameRecord(key: key, completedAt: now, metrics: metrics),
      );
    }

    final bests = repository.bests(
      key: key,
      definition: solitaireRecordDefinition,
      now: now,
    );

    expect(bests.daily?.record.metrics, {'time': 240000, 'moves': 110});
    expect(bests.weekly?.record.metrics, bests.daily?.record.metrics);
    expect(bests.overall?.record.metrics, bests.daily?.record.metrics);
  });
}
