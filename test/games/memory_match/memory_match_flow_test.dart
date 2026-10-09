import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/game_record_repository.dart';
import 'package:tap_tussle/core/haptic_service.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/core/mini_game.dart';
import 'package:tap_tussle/core/sound_service.dart';
import 'package:tap_tussle/features/game_setup/game_setup_screen.dart';
import 'package:tap_tussle/features/match/match_screen.dart';
import 'package:tap_tussle/games/memory_match/memory_match_controller.dart';
import 'package:tap_tussle/games/memory_match/memory_match_model.dart';
import 'package:tap_tussle/games/memory_match/memory_match_view.dart';

void completeEveryPair(MemoryMatchController controller) {
  for (var pair = 0; pair < controller.model.pairCount; pair++) {
    final indexes = <int>[];
    for (var index = 0; index < controller.model.cardCount; index++) {
      if (controller.model.deck[index] == pair) indexes.add(index);
    }
    controller
      ..selectCard(indexes[0])
      ..selectCard(indexes[1]);
  }
}

class RecordingSoundPlayer implements SoundPlayer {
  final played = <SoundEffect>[];

  @override
  Future<void> play(SoundEffect effect) async => played.add(effect);

  @override
  void setVolume(double value) {}
}

class RecordingHapticPlayer implements HapticPlayer {
  var lightImpacts = 0;
  var mediumImpacts = 0;

  @override
  void setEnabled(bool value) {}

  @override
  Future<void> preview() async => lightImpacts++;

  @override
  Future<void> paddleHit() async => mediumImpacts++;
}

void main() {
  test('solo completion publishes moves and active play time', () {
    var now = DateTime(2026, 9, 26, 12);
    final session = MatchSession(
      options: MatchOptions.solo(difficulty: BotDifficulty.easy),
    );
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.easy,
      random: Random(20),
      openingPreviewDuration: Duration.zero,
      now: () => now,
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    session.start();
    now = now.add(const Duration(seconds: 2));
    session.pause();
    now = now.add(const Duration(seconds: 5));
    session.resume();
    now = now.add(const Duration(milliseconds: 1300));
    completeEveryPair(controller);

    expect(session.phase, MatchPhase.finished);
    expect(session.outcome, MatchOutcome.completed);
    expect(session.scores, [6]);
    expect(session.recordMetrics, {'moves': 6, 'time': 3300});
    expect(session.resultDetails, contains('Completed in 6 moves'));
    expect(session.resultDetails, contains('3.3s'));
  });

  test('two-player completion publishes pair scores and winner', () {
    final session = MatchSession(
      options: MatchOptions.friend(difficulty: BotDifficulty.easy),
    );
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.easy,
      random: Random(21),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    session.start();
    completeEveryPair(controller);

    expect(session.phase, MatchPhase.finished);
    expect(session.outcome, MatchOutcome.winner);
    expect(session.winner, 0);
    expect(session.scores, [6, 0]);
    expect(session.recordMetrics, isNull);
    expect(session.resultDetails, isNull);
  });

  test('bot match completion preserves shared scores and result labels', () {
    final session = MatchSession(
      options: MatchOptions.bot(difficulty: BotDifficulty.easy),
    );
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.easy,
      random: Random(24),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    session.start();
    completeEveryPair(controller);

    expect(session.phase, MatchPhase.finished);
    expect(session.outcome, MatchOutcome.winner);
    expect(session.winner, 0);
    expect(session.scores, [6, 0]);
    expect(session.resultDetails, isNull);
  });

  testWidgets('production view celebrates the final pair before results', (
    tester,
  ) async {
    final options = MatchOptions.solo(difficulty: BotDifficulty.easy);
    final session = MatchSession(options: options)..start();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: MemoryMatchView(session: session, options: options),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    final board = tester.widget<MemoryMatchBoard>(
      find.byType(MemoryMatchBoard),
    );
    completeEveryPair(board.controller);
    await tester.pump();

    expect(session.phase, MatchPhase.playing);
    expect(find.text('MATCH!'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(12));

    await tester.pump(const Duration(milliseconds: 621));
    expect(find.text('ALL PAIRS FOUND!'), findsOneWidget);
    expect(session.phase, MatchPhase.playing);

    await tester.pump(const Duration(milliseconds: 679));
    expect(session.phase, MatchPhase.finished);
  });

  testWidgets('solo and friend modes choose difficulty and build that grid', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    addTearDown(settings.dispose);
    final game = gameCatalog.singleWhere((game) => game.id == 'memory-match');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: GameSetupScreen(game: game, settings: settings),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-solo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bot-difficulty-slider')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('start-bot-match')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MemoryMatchView), findsOneWidget);
    expect(find.byKey(const ValueKey('memory-card-15')), findsOneWidget);
    expect(find.byKey(const ValueKey('memory-card-16')), findsNothing);

    await tester.tap(find.byTooltip('Change options'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('change-options')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-vs-friend')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bot-difficulty-slider')), findsOneWidget);
  });

  testWidgets('bot setup selects a difficulty and starts a locked bot match', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    addTearDown(settings.dispose);
    final game = gameCatalog.singleWhere((game) => game.id == 'memory-match');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: GameSetupScreen(game: game, settings: settings),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-vs-bot')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('bot-difficulty-slider')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('start-bot-match')));
    await tester.tap(find.byKey(const ValueKey('start-bot-match')));
    await tester.pumpAndSettle();
    expect(find.byType(MemoryMatchView), findsOneWidget);

    final board = tester.widget<MemoryMatchBoard>(
      find.byType(MemoryMatchBoard),
    );
    final mismatch = <int>[0];
    mismatch.add(
      board.controller.model.deck.indexWhere(
        (pair) => pair != board.controller.model.deck.first,
      ),
    );
    await tester.tap(find.byKey(ValueKey('memory-card-${mismatch[0]}')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('memory-card-${mismatch[1]}')));
    await tester.pump(const Duration(milliseconds: 850));

    expect(find.text('BOT THINKING…'), findsOneWidget);
    expect(find.byKey(const ValueKey('memory-bot-thinking')), findsOneWidget);
    expect(board.controller.acceptsInput, isFalse);
  });

  testWidgets('solo completion is persisted once for its difficulty', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    addTearDown(settings.dispose);
    final game = gameCatalog.singleWhere((game) => game.id == 'memory-match');
    MatchSession? capturedSession;
    final fixture = MiniGame(
      id: game.id,
      title: game.title,
      subtitle: game.subtitle,
      instructions: game.instructions,
      icon: game.icon,
      supportedModes: game.supportedModes,
      supportedPlayerCounts: game.supportedPlayerCounts,
      difficultyType: game.difficultyType,
      recordDefinition: game.recordDefinition,
      build: (session, _) {
        capturedSession = session;
        return const SizedBox.expand();
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: MatchScreen(
          game: fixture,
          options: MatchOptions.solo(difficulty: BotDifficulty.hard),
          startImmediately: true,
          recordRepository: settings.recordRepository,
          recordVariant: 'hard',
        ),
      ),
    );
    capturedSession!.reportCompletion(
      scores: const [12],
      details: 'Completed in 15 moves.',
      recordMetrics: const {'moves': 15, 'time': 9000},
    );
    await tester.pumpAndSettle();

    const key = GameRecordKey(
      gameId: 'memory-match',
      recordType: 'solo',
      variant: 'hard',
    );
    final records = settings.recordRepository.recordsFor(key);
    expect(records, hasLength(1));
    expect(records.single.metrics, {'moves': 15, 'time': 9000});
    expect(find.text('Complete!'), findsOneWidget);
  });

  testWidgets('card flips and pairs use shared sounds and haptics', (
    tester,
  ) async {
    final sounds = RecordingSoundPlayer();
    final haptics = RecordingHapticPlayer();
    SoundEffects.configure(sounds);
    HapticEffects.configure(haptics);
    final options = MatchOptions.friend(difficulty: BotDifficulty.easy);
    final session = MatchSession(options: options);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: MemoryMatchView(session: session, options: options),
      ),
    );
    session.start();
    await tester.pump();
    final board = tester.widget<MemoryMatchBoard>(
      find.byType(MemoryMatchBoard),
    );
    final pair = board.controller.model.deck.first;
    final indexes = <int>[];
    for (var index = 0; index < board.controller.model.cardCount; index++) {
      if (board.controller.model.deck[index] == pair) indexes.add(index);
    }

    await tester.tap(find.byKey(ValueKey('memory-card-${indexes[0]}')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('memory-card-${indexes[1]}')));
    await tester.pump();
    expect(
      find.byKey(ValueKey('memory-card-feedback-${indexes[0]}-match')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('memory-card-feedback-${indexes[1]}-match')),
      findsOneWidget,
    );

    final unmatched = <int>[];
    for (var index = 0; index < board.controller.model.cardCount; index++) {
      if (board.controller.model.cardAt(index).state ==
              MemoryCardState.hidden &&
          (unmatched.isEmpty ||
              board.controller.model.deck[index] !=
                  board.controller.model.deck[unmatched.first])) {
        unmatched.add(index);
      }
      if (unmatched.length == 2) break;
    }
    await tester.tap(find.byKey(ValueKey('memory-card-${unmatched[0]}')));
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('memory-card-${unmatched[1]}')));
    await tester.pump();
    expect(
      find.byKey(ValueKey('memory-card-feedback-${unmatched[0]}-mismatch')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('memory-card-feedback-${unmatched[1]}-mismatch')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 620));
    expect(
      find.byKey(ValueKey('memory-card-feedback-${unmatched[0]}-mismatch')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey('memory-card-feedback-${unmatched[1]}-mismatch')),
      findsNothing,
    );

    expect(
      sounds.played,
      containsAllInOrder([
        SoundEffect.cardShuffle,
        SoundEffect.cardFlip,
        SoundEffect.cardFlip,
        SoundEffect.matchPair,
      ]),
    );
    expect(sounds.played, contains(SoundEffect.uiInvalid));
    expect(haptics.lightImpacts, 3);
    expect(haptics.mediumImpacts, 1);
  });
}
