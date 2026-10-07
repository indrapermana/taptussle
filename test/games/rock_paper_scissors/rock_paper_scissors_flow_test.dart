import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/app/game_logo_assets.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/haptic_service.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/core/mini_game.dart';
import 'package:tap_tussle/core/sound_service.dart';
import 'package:tap_tussle/features/game_setup/game_setup_screen.dart';
import 'package:tap_tussle/features/match/match_screen.dart';
import 'package:tap_tussle/games/rock_paper_scissors/rock_paper_scissors_controller.dart';
import 'package:tap_tussle/games/rock_paper_scissors/rock_paper_scissors_model.dart';
import 'package:tap_tussle/games/rock_paper_scissors/rock_paper_scissors_view.dart';

class _RecordingSoundPlayer implements SoundPlayer {
  final played = <SoundEffect>[];

  @override
  Future<void> play(SoundEffect effect) async => played.add(effect);

  @override
  void setVolume(double value) {}
}

class _RecordingHapticPlayer implements HapticPlayer {
  var lightImpacts = 0;
  var mediumImpacts = 0;

  @override
  Future<void> paddleHit() async => mediumImpacts++;

  @override
  Future<void> preview() async => lightImpacts++;

  @override
  void setEnabled(bool value) {}
}

void main() {
  final game = gameCatalog.singleWhere(
    (game) => game.id == 'rock-paper-scissors',
  );

  test('catalog metadata enables two-player friend and bot setup', () {
    expect(game.artworkAsset, gameLogoAssets['rock-paper-scissors']);
    expect(game.supportedPlayerCounts, {PlayerCount.two});
    expect(game.supportedModes, {PlayMode.friend, PlayMode.bot});
    expect(game.difficultyType, DifficultyType.bot);
    expect(
      game.matchLabel!(MatchOptions.friend(winningScore: 5)),
      'FIRST TO 5',
    );
  });

  testWidgets('friend result uses shared result and rematch flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: MatchScreen(
          game: game,
          options: MatchOptions.friend(winningScore: 1),
          startImmediately: true,
        ),
      ),
    );
    final board = tester.widget<RockPaperScissorsBoard>(
      find.byType(RockPaperScissorsBoard),
    );
    board.controller.selectChoice(RockPaperScissorsChoice.rock);
    board.controller.confirmHandoff();
    board.controller.selectChoice(RockPaperScissorsChoice.scissors);
    await tester.pumpAndSettle();

    expect(find.text('Player 1 wins!'), findsOneWidget);
    expect(find.text('1'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();

    expect(board.controller.model.scores, [0, 0]);
    expect(board.controller.model.lastRound, isNull);
    expect(board.controller.phase, RockPaperScissorsRoundPhase.choosing);
  });

  testWidgets('shared setup persists favourite and opens bot difficulty', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    addTearDown(settings.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: GameSetupScreen(game: game, settings: settings),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    expect(settings.isFavourite('rock-paper-scissors'), isTrue);
    expect(find.byTooltip('Remove from favourites'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-vs-bot')));
    await tester.pumpAndSettle();
    expect(find.text('Bot difficulty'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('start-bot-match')));
    await tester.tap(find.byKey(const ValueKey('start-bot-match')));
    await tester.pumpAndSettle();
    expect(find.byType(RockPaperScissorsView), findsOneWidget);
  });

  testWidgets('choice, handoff, reveal, and score play shared effects', (
    tester,
  ) async {
    final sounds = _RecordingSoundPlayer();
    final haptics = _RecordingHapticPlayer();
    SoundEffects.configure(sounds);
    HapticEffects.configure(haptics);
    final options = MatchOptions.friend(winningScore: 2);
    final session = MatchSession(options: options)..start();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: RockPaperScissorsView(session: session, options: options),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('rps-choice-rock')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rps-handoff-ready')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rps-choice-scissors')));
    await tester.pump();

    expect(
      sounds.played,
      containsAllInOrder([
        SoundEffect.uiConfirm,
        SoundEffect.uiTap,
        SoundEffect.roundReveal,
        SoundEffect.scoreCool,
      ]),
    );
    expect(haptics.lightImpacts, 1);
    expect(haptics.mediumImpacts, 1);
  });
}
