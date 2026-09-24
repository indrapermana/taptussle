import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/app/tap_tussle_app.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/core/mini_game.dart';
import 'package:tap_tussle/features/game_setup/game_setup_screen.dart';
import 'package:tap_tussle/games/paddle_duel/paddle_duel_presentation.dart';

Future<AppSettings> settingsFor(
  WidgetTester tester, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings(await SharedPreferences.getInstance());
  addTearDown(settings.dispose);
  return settings;
}

Future<void> setDifficulty(
  WidgetTester tester,
  BotDifficulty difficulty,
) async {
  final slider = tester.getRect(find.byType(Slider));
  // Slider tracks have a horizontal inset, so avoid its outer hit-test edge.
  final fraction = .1 + (.8 * difficulty.index / 2);
  await tester.tapAt(
    Offset(slider.left + slider.width * fraction, slider.center.dy),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final difficulty in BotDifficulty.values) {
    testWidgets(
      '${difficulty.label} bot flow keeps choices and protects bot controls',
      (tester) async {
        final settings = await settingsFor(tester);
        await tester.pumpWidget(TapTussleApp(settings: settings));
        final paddleDuelCard = find.byKey(
          const ValueKey('game-card-paddle-duel'),
        );
        await tester.ensureVisible(paddleDuelCard);
        await tester.pumpAndSettle();
        await tester.tap(paddleDuelCard);
        await tester.pumpAndSettle();
        expect(find.text('How to play'), findsOneWidget);
        expect(find.text('Play vs Friend'), findsOneWidget);
        await tester.tap(find.text('Play vs Bot'));
        await tester.pumpAndSettle();
        expect(find.text('Bot difficulty'), findsOneWidget);
        await setDifficulty(tester, difficulty);
        expect(find.text('Play ${difficulty.label}'), findsOneWidget);
        await tester.tap(find.text('Play ${difficulty.label}'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final game = tester
            .widget<PaddleDuelPresentation>(find.byType(PaddleDuelPresentation))
            .game;
        expect(game.session.phase, MatchPhase.playing);
        expect(game.bot!.difficulty, difficulty);
        expect(find.text('You  0'), findsOneWidget);
        expect(find.text('0  Bot'), findsOneWidget);

        final area = tester.getRect(find.byKey(const ValueKey('paddle-court')));
        final top = await tester.startGesture(
          Offset(area.left + area.width * .85, area.top + area.height * .2),
          pointer: 3,
        );
        expect(game.model.paddles[1], 180);
        await top.moveTo(Offset(area.left + area.width * .15, area.bottom - 2));
        expect(game.model.paddles, [180, 180]);
        await top.up();

        final bottom = await tester.startGesture(
          Offset(area.left + area.width * .25, area.bottom - 2),
          pointer: 4,
        );
        expect(game.model.paddles[0], closeTo(90, .1));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        final paused = List.of(game.model.paddles);
        game.update(.1);
        expect(game.model.paddles, paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.tap(find.text('Resume match'));
        await tester.pump();
        await bottom.moveTo(
          Offset(area.left + area.width * .75, area.bottom - 2),
        );
        expect(game.model.paddles[0], closeTo(90, .1));
        await bottom.up();

        for (var i = 0; i < 7; i++) {
          game.model
            ..serveRemaining = 0
            ..ballY = -6
            ..velocityY = -400;
          game.update(.02);
        }
        await tester.pump();
        expect(find.text('You win!'), findsOneWidget);
        await tester.tap(find.text('Play again'));
        await tester.pump();
        expect(game.model.scores, [0, 0]);
        expect(game.bot!.difficulty, difficulty);

        await tester.tap(find.byTooltip('Pause match'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Change options'));
        await tester.pumpAndSettle();
        expect(find.text('How to play'), findsOneWidget);
        expect(settings.preferencesFor('paddle-duel').mode, PlayMode.bot);
        expect(settings.preferencesFor('paddle-duel').difficulty, difficulty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('game grid is two columns and favourite order remains stable', (
    tester,
  ) async {
    final settings = await settingsFor(tester, size: const Size(390, 1000));
    MiniGame fixture(String id) => MiniGame(
      id: id,
      title: id,
      subtitle: 'Test game',
      instructions: 'Test',
      icon: Icons.games,
      build: (_, options) => const SizedBox(),
    );
    final games = [
      'Alpha',
      'Beta',
      'Gamma',
      'Delta',
      'Epsilon',
    ].map(fixture).toList();
    await tester.pumpWidget(TapTussleApp(settings: settings, games: games));
    final alpha = tester.getRect(find.byKey(const ValueKey('game-card-Alpha')));
    final beta = tester.getRect(find.byKey(const ValueKey('game-card-Beta')));
    expect(alpha.top, beta.top);
    expect(alpha.left, lessThan(beta.left));

    await tester.tap(find.byKey(const ValueKey('game-card-Beta')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to favourites'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    final favouriteBeta = tester.getRect(
      find.byKey(const ValueKey('game-card-Beta')),
    );
    final nextAlpha = tester.getRect(
      find.byKey(const ValueKey('game-card-Alpha')),
    );
    expect(favouriteBeta.top, nextAlpha.top);
    expect(favouriteBeta.left, lessThan(nextAlpha.left));

    await tester.tap(find.byKey(const ValueKey('game-card-Beta')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove favourite'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    final restoredAlpha = tester.getRect(
      find.byKey(const ValueKey('game-card-Alpha')),
    );
    final restoredBeta = tester.getRect(
      find.byKey(const ValueKey('game-card-Beta')),
    );
    expect(restoredAlpha.left, lessThan(restoredBeta.left));
  });

  testWidgets('saved bot selection opens on the separate difficulty page', (
    tester,
  ) async {
    final settings = await settingsFor(tester);
    await settings.saveGamePreferences(
      'paddle-duel',
      const GamePreferences(mode: PlayMode.bot, difficulty: BotDifficulty.hard),
    );
    await settings.setFavourite('paddle-duel', true);
    final restored = AppSettings(await SharedPreferences.getInstance());
    addTearDown(restored.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: GameSetupScreen(
          game: gameCatalog.firstWhere((game) => game.id == 'paddle-duel'),
          settings: restored,
        ),
      ),
    );
    expect(find.text('Remove favourite'), findsOneWidget);
    await tester.tap(find.text('Play vs Bot'));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 2);
    expect(find.text('Play Hard'), findsOneWidget);
    expect(find.byType(PaddleDuelPresentation), findsNothing);
  });

  testWidgets('small screen and large text allow bot setup without overflow', (
    tester,
  ) async {
    final settings = await settingsFor(tester, size: const Size(320, 568));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          devicePixelRatio: 1,
          textScaler: TextScaler.linear(1.5),
        ),
        child: MaterialApp(
          home: GameSetupScreen(
            game: gameCatalog.firstWhere((game) => game.id == 'paddle-duel'),
            settings: settings,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          devicePixelRatio: 1,
          textScaler: TextScaler.linear(1.5),
        ),
        child: MaterialApp(
          home: BotDifficultyScreen(
            game: gameCatalog.firstWhere((game) => game.id == 'paddle-duel'),
            settings: settings,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    await setDifficulty(tester, BotDifficulty.hard);
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Play Hard').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
