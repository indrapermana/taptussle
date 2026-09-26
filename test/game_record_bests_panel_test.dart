import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/game_record_repository.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/mini_game.dart';
import 'package:tap_tussle/features/game_setup/game_record_bests_panel.dart';
import 'package:tap_tussle/features/game_setup/game_setup_screen.dart';

final definition = GameRecordDefinition(
  primaryMetric: const RecordMetricDefinition(
    id: 'score',
    label: 'Score',
    format: RecordMetricFormat.integer,
    sortOrder: RecordSortOrder.higherIsBetter,
  ),
  tieBreakers: const [
    RecordMetricDefinition(
      id: 'timeMs',
      label: 'Time',
      format: RecordMetricFormat.duration,
      sortOrder: RecordSortOrder.lowerIsBetter,
    ),
  ],
);

MiniGame soloGame() => MiniGame(
  id: 'solo-record-fixture',
  title: 'Solo Record Fixture',
  subtitle: 'Test',
  instructions: 'Set a record.',
  icon: Icons.emoji_events_rounded,
  supportedModes: const {PlayMode.solo},
  supportedPlayerCounts: const {PlayerCount.one},
  difficultyType: DifficultyType.challenge,
  recordDefinition: definition,
  build: (_, _) => const SizedBox.expand(),
);

GameRecord record(int day, int score, int timeMs) => GameRecord(
  key: const GameRecordKey(
    gameId: 'solo-record-fixture',
    recordType: 'solo',
    variant: 'normal',
  ),
  completedAt: DateTime(2026, 9, day, 12),
  metrics: {'score': score, 'timeMs': timeMs},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('records panel presents daily weekly and overall best values', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    addTearDown(settings.dispose);
    final game = soloGame();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: Scaffold(
          body: GameRecordBestsPanel(
            game: game,
            settings: settings,
            now: DateTime(2026, 9, 23, 18),
          ),
        ),
      ),
    );
    expect(find.text('—'), findsNWidgets(3));

    for (final entry in [
      record(20, 90, 70000),
      record(21, 70, 80000),
      record(23, 50, 90000),
    ]) {
      await settings.recordRepository.addRecord(
        definition: definition,
        record: entry,
      );
    }
    await tester.pump();

    expect(find.text('DAILY'), findsOneWidget);
    expect(find.text('WEEKLY'), findsOneWidget);
    expect(find.text('OVERALL'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('record-DAILY-primary')))
          .data,
      '50',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('record-WEEKLY-primary')))
          .data,
      '70',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('record-OVERALL-primary')))
          .data,
      '90',
    );
    expect(find.text('Time 1:30'), findsOneWidget);
    expect(find.text('Time 1:20'), findsOneWidget);
    expect(find.text('Time 1:10'), findsOneWidget);
  });

  testWidgets('solo game setup includes the shared records panel', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: GameSetupScreen(game: soloGame(), settings: settings),
      ),
    );

    expect(find.byKey(const ValueKey('game-record-bests')), findsOneWidget);
    expect(find.text('YOUR BEST'), findsOneWidget);
    expect(find.text('NORMAL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
