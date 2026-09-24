import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/tap_tussle_app.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/paddle_duel/paddle_duel_game.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<AppSettings> launchCleanApp(WidgetTester tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    final settings = AppSettings(preferences);
    await tester.pumpWidget(TapTussleApp(settings: settings));
    await tester.pumpAndSettle();
    return settings;
  }

  Future<void> setDifficulty(
    WidgetTester tester,
    BotDifficulty difficulty,
  ) async {
    final slider = tester.getRect(
      find.byKey(const ValueKey('bot-difficulty-slider')),
    );
    final fraction = .1 + (.8 * difficulty.index / 2);
    await tester.tapAt(
      Offset(slider.left + slider.width * fraction, slider.center.dy),
    );
    await tester.pumpAndSettle();
  }

  Future<void> forcePlayerOneWin(
    WidgetTester tester,
    PaddleDuelGame game,
  ) async {
    for (var point = 0; point < game.session.options.winningScore; point++) {
      game.model
        ..serveRemaining = 0
        ..ballY = -6
        ..velocityY = -400;
      game.update(.02);
    }
    await tester.pump();
  }

  testWidgets('friend match journey persists favourite and supports recovery', (
    tester,
  ) async {
    final settings = await launchCleanApp(tester);
    addTearDown(settings.dispose);

    await tester.tap(find.byKey(const ValueKey('game-card-paddle-duel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    expect(settings.isFavourite('paddle-duel'), isTrue);

    await tester.tap(find.byKey(const ValueKey('play-vs-friend')));
    await tester.pump(const Duration(milliseconds: 500));
    final game = tester
        .widget<GameWidget<PaddleDuelGame>>(
          find.byType(GameWidget<PaddleDuelGame>),
        )
        .game!;
    expect(game.session.phase, MatchPhase.playing);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Time out'), findsOneWidget);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('resume-match')));
    await tester.pump();

    await forcePlayerOneWin(tester, game);
    expect(find.text('Player 1 wins!'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();
    expect(game.model.scores, [0, 0]);

    await tester.tap(find.byTooltip('Pause match'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('change-options')));
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(settings.isFavourite('paddle-duel'), isTrue);
  });

  testWidgets('each bot slider position starts the corresponding bot', (
    tester,
  ) async {
    final settings = await launchCleanApp(tester);
    addTearDown(settings.dispose);

    for (final difficulty in BotDifficulty.values) {
      await tester.tap(find.byKey(const ValueKey('game-card-paddle-duel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play-vs-bot')));
      await tester.pumpAndSettle();
      await setDifficulty(tester, difficulty);
      expect(find.text('Play ${difficulty.label}'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('start-bot-match')));
      await tester.pump(const Duration(milliseconds: 500));

      final game = tester
          .widget<GameWidget<PaddleDuelGame>>(
            find.byType(GameWidget<PaddleDuelGame>),
          )
          .game!;
      expect(game.bot!.difficulty, difficulty);

      await tester.tap(find.byTooltip('Pause match'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('change-options')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    expect(settings.preferencesFor('paddle-duel').mode, PlayMode.bot);
    expect(
      settings.preferencesFor('paddle-duel').difficulty,
      BotDifficulty.hard,
    );
  });
}
