import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/features/game_setup/game_setup_screen.dart';
import 'package:tap_tussle/features/home/home_screen.dart';
import 'package:tap_tussle/features/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppSettings> settings() async {
    SharedPreferences.setMockInitialValues({});
    final value = AppSettings(await SharedPreferences.getInstance());
    addTearDown(value.dispose);
    return value;
  }

  void usePhone(WidgetTester tester, {double textScale = 1}) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Widget app(Widget home) =>
      MaterialApp(theme: buildTapTussleTheme(), home: home);

  Future<void> expectAccessibleTapTargets(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  testWidgets('home controls are labeled and comfortably tappable', (
    tester,
  ) async {
    usePhone(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      app(HomeScreen(settings: await settings(), games: gameCatalog)),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp('1 Player')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('2 Players')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Up to 4 Players')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Open Paddle Duel')), findsOneWidget);
    await expectAccessibleTapTargets(tester);
    semantics.dispose();
  });

  testWidgets('settings remains usable with enlarged text', (tester) async {
    usePhone(tester, textScale: 2);
    PackageInfo.setMockInitialValues(
      appName: 'Tap Tussle',
      packageName: 'com.indesyakaryadigital.tapTussle',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await tester.pumpWidget(app(SettingsScreen(settings: await settings())));
    await tester.pumpAndSettle();

    expect(find.text('Grown-up Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectAccessibleTapTargets(tester);
  });

  testWidgets('game setup exposes labeled primary choices', (tester) async {
    usePhone(tester, textScale: 1.5);
    final paddle = gameCatalog.singleWhere((game) => game.id == 'paddle-duel');
    await tester.pumpWidget(
      app(GameSetupScreen(game: paddle, settings: await settings())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Play Together'), findsOneWidget);
    expect(find.text('Play with Bot'), findsOneWidget);
    expect(find.byTooltip('Add to favourites'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectAccessibleTapTargets(tester);
  });
}
