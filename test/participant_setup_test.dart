import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/mini_game.dart';
import 'package:tap_tussle/features/game_setup/game_setup_screen.dart';

Future<AppSettings> _settings(WidgetTester tester) async {
  tester.view.physicalSize = const Size(500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings(await SharedPreferences.getInstance());
  addTearDown(settings.dispose);
  return settings;
}

Widget _app(MiniGame game, AppSettings settings) => MaterialApp(
  theme: buildTapTussleTheme(),
  home: GameSetupScreen(game: game, settings: settings),
);

void main() {
  testWidgets('multi-player setup configures ordered human and bot seats', (
    tester,
  ) async {
    final settings = await _settings(tester);
    MatchOptions? startedOptions;
    final game = MiniGame(
      id: 'flexible-fixture',
      title: 'Flexible Fixture',
      subtitle: 'Test',
      instructions: 'Configure the players.',
      icon: Icons.groups_rounded,
      supportedModes: const {PlayMode.friend, PlayMode.bot},
      supportedPlayerCounts: const {
        PlayerCount.two,
        PlayerCount.three,
        PlayerCount.four,
      },
      difficultyType: DifficultyType.bot,
      build: (_, options) {
        startedOptions = options;
        return const Center(child: Text('Fixture started'));
      },
    );

    await tester.pumpWidget(_app(game, settings));
    expect(find.text('Set Up Players'), findsOneWidget);
    expect(find.text('Play vs Friend'), findsNothing);
    expect(find.text('Play vs Bot'), findsNothing);

    await tester.tap(find.text('Set Up Players'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('participant-count-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('participant-count-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('participant-count-4')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('participant-count-3')));
    await tester.pumpAndSettle();
    final secondKind = find.byKey(const ValueKey('participant-kind-1'));
    await tester.ensureVisible(secondKind);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: secondKind, matching: find.text('Bot')),
    );
    await tester.pumpAndSettle();

    final secondName = find.byKey(const ValueKey('participant-name-1'));
    await tester.ensureVisible(secondName);
    await tester.enterText(secondName, 'Rival Bot');
    final difficulty = find.byKey(
      const ValueKey('participant-difficulty-1-normal'),
    );
    await tester.ensureVisible(difficulty);
    await tester.tap(difficulty);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hard').last);
    await tester.pumpAndSettle();

    final firstColor = tester.widget<DropdownButton<ParticipantColor>>(
      find.descendant(
        of: find.byKey(const ValueKey('participant-color-0-mint')),
        matching: find.byType(DropdownButton<ParticipantColor>),
      ),
    );
    expect(firstColor.items!.map((item) => item.value), [
      ParticipantColor.mint,
      ParticipantColor.violet,
    ]);

    final start = find.byKey(const ValueKey('start-configured-match'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(find.text('Fixture started'), findsOneWidget);
    expect(startedOptions!.mode, PlayMode.bot);
    expect(startedOptions!.participants, hasLength(3));
    expect(
      startedOptions!.participants.map(
        (participant) => participant.displayName,
      ),
      ['Player 1', 'Rival Bot', 'Player 3'],
    );
    expect(startedOptions!.participants[1].kind, ParticipantKind.bot);
    expect(startedOptions!.participants[1].botDifficulty, BotDifficulty.hard);
    expect(
      startedOptions!.participants
          .map((participant) => participant.color)
          .toSet(),
      hasLength(3),
    );
    expect(settings.preferencesFor(game.id).mode, PlayMode.bot);
    expect(settings.preferencesFor(game.id).difficulty, BotDifficulty.hard);
    expect(tester.takeException(), isNull);
  });

  testWidgets('solo-only games show only the supported setup action', (
    tester,
  ) async {
    final settings = await _settings(tester);
    MatchOptions? startedOptions;
    final game = MiniGame(
      id: 'solo-fixture',
      title: 'Solo Fixture',
      subtitle: 'Test',
      instructions: 'Play alone.',
      icon: Icons.person_rounded,
      supportedModes: const {PlayMode.solo},
      supportedPlayerCounts: const {PlayerCount.one},
      build: (_, options) {
        startedOptions = options;
        return const Center(child: Text('Solo started'));
      },
    );

    await tester.pumpWidget(_app(game, settings));
    expect(find.text('Play Solo'), findsOneWidget);
    expect(find.text('Set Up Players'), findsNothing);
    expect(find.text('Play vs Friend'), findsNothing);
    expect(find.text('Play vs Bot'), findsNothing);

    await tester.tap(find.text('Play Solo'));
    await tester.pumpAndSettle();

    expect(find.text('Solo started'), findsOneWidget);
    expect(startedOptions!.mode, PlayMode.solo);
    expect(startedOptions!.participants, hasLength(1));
    expect(startedOptions!.participants.single.kind, ParticipantKind.human);
    expect(tester.takeException(), isNull);
  });
}
