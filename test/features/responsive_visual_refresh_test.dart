import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/core/mini_game.dart';
import 'package:tap_tussle/features/match/match_screen.dart';
import 'package:tap_tussle/features/home/home_screen.dart';
import 'package:tap_tussle/features/settings/graphics_preview_screen.dart';
import 'package:tap_tussle/features/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppSettings> createSettings(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    addTearDown(settings.dispose);
    return settings;
  }

  void useCompactPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Widget home) => MaterialApp(
    theme: buildTapTussleTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.5)),
      child: child!,
    ),
    home: home,
  );

  testWidgets('arcade lobby supports compact enlarged text', (tester) async {
    useCompactPhone(tester);
    final settings = await createSettings(tester);
    await tester.pumpWidget(
      app(HomeScreen(settings: settings, games: gameCatalog)),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Settings'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('game-card-paddle-duel')),
      300,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-card-paddle-duel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings and legal content support compact enlarged text', (
    tester,
  ) async {
    useCompactPhone(tester);
    final settings = await createSettings(tester);
    await tester.pumpWidget(app(SettingsScreen(settings: settings)));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Privacy Policy'), 400);
    await tester.ensureVisible(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Changes'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('graphics comparison supports compact enlarged text', (
    tester,
  ) async {
    useCompactPhone(tester);
    final settings = await createSettings(tester);
    await tester.pumpWidget(app(GraphicsPreviewScreen(settings: settings)));
    await tester.pump();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('candidate-resolution-selector')),
      500,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('apply-graphics-settings')),
      400,
    );
    await tester.pumpAndSettle();
    expect(find.text('Apply candidate settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('match ready and result overlays support compact enlarged text', (
    tester,
  ) async {
    useCompactPhone(tester);
    late MatchSession session;
    final game = MiniGame(
      id: 'responsive-test',
      title: 'Responsive Test',
      subtitle: 'Test',
      instructions:
          'Take your side, watch your rival, and tap at exactly the right moment.',
      icon: Icons.touch_app_rounded,
      build: (match, _) {
        session = match;
        return const SizedBox.expand();
      },
    );
    await tester.pumpWidget(
      app(
        MatchScreen(game: game, options: MatchOptions.friend(winningScore: 5)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start match'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Start match'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start match'));
    await tester.pump();
    session.reportNonPointResult(
      winner: null,
      details: 'Both rivals held their ground. Another round?',
    );
    await tester.pumpAndSettle();
    expect(find.text('Draw!'), findsOneWidget);
    expect(find.text('Play again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
