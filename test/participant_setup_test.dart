import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
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

Widget _app(
  MiniGame game,
  AppSettings settings, {
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: buildTapTussleTheme(),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: GameSetupScreen(game: game, settings: settings),
);

MiniGame _flexibleGame({Widget Function(MatchSession, MatchOptions)? build}) =>
    MiniGame(
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
      build: build ?? (_, _) => const SizedBox.shrink(),
    );

void main() {
  testWidgets('multi-player setup configures ordered human and bot seats', (
    tester,
  ) async {
    final settings = await _settings(tester);
    MatchOptions? startedOptions;
    final game = _flexibleGame(
      build: (_, options) {
        startedOptions = options;
        return const Center(child: Text('Fixture started'));
      },
    );

    await tester.pumpWidget(_app(game, settings));
    expect(find.text('Set Up 2–4 Players'), findsOneWidget);
    expect(find.text('Play Together'), findsNothing);
    expect(find.text('Play with Bot'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('configure-participants')));
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

    final hardDifficulty = find.byKey(
      const ValueKey('participant-difficulty-1-hard'),
    );
    await tester.ensureVisible(hardDifficulty);
    await tester.tap(hardDifficulty);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('participant-color-option-0-mint')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('participant-color-option-0-violet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('participant-color-option-0-coral')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('participant-color-option-0-gold')),
      findsNothing,
    );
    final violet = find.byKey(
      const ValueKey('participant-color-option-0-violet'),
    );
    await tester.fling(find.byType(ListView), const Offset(0, 2000), 5000);
    await tester.pumpAndSettle();
    await tester.tap(violet);
    await tester.pumpAndSettle();
    final star = find.byKey(const ValueKey('participant-token-option-0-star'));
    await tester.tap(star);
    await tester.pumpAndSettle();

    final start = find.byKey(const ValueKey('start-configured-match'));
    await tester.scrollUntilVisible(start, 500);
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(find.text('Fixture started'), findsOneWidget);
    expect(startedOptions!.mode, PlayMode.bot);
    expect(startedOptions!.participants, hasLength(3));
    expect(
      startedOptions!.participants.map(
        (participant) => participant.displayName,
      ),
      ['Player 1', 'Bot 2', 'Player 3'],
    );
    expect(startedOptions!.participants[1].kind, ParticipantKind.bot);
    expect(startedOptions!.participants[1].botDifficulty, BotDifficulty.hard);
    expect(startedOptions!.participants.first.color, ParticipantColor.violet);
    expect(startedOptions!.participants.first.token, ParticipantToken.star);
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

  testWidgets(
    'two-to-four-player layouts support compact phones and enlarged text',
    (tester) async {
      final settings = await _settings(tester);
      tester.view.physicalSize = const Size(320, 568);
      final game = _flexibleGame();

      await tester.pumpWidget(
        _app(game, settings, textScaler: const TextScaler.linear(1.5)),
      );
      expect(tester.takeException(), isNull, reason: 'game setup overflowed');
      await tester.tap(find.byKey(const ValueKey('configure-participants')));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'participant setup initially overflowed',
      );

      for (final count in [2, 3, 4]) {
        await tester.fling(find.byType(ListView), const Offset(0, 2000), 5000);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('participant-count-$count')));
        await tester.pumpAndSettle();

        for (var index = 0; index < count; index++) {
          final participant = find.bySemanticsLabel(
            'Player ${index + 1} setup',
          );
          await tester.scrollUntilVisible(participant, 300);
          await tester.pumpAndSettle();
          expect(participant, findsOneWidget);
          final exception = tester.takeException();
          expect(
            exception,
            isNull,
            reason:
                'count $count participant $index: '
                '${exception is FlutterError ? exception.toStringDeep() : exception}',
          );
        }
      }

      final start = find.byKey(const ValueKey('start-configured-match'));
      await tester.scrollUntilVisible(start, 300);
      await tester.pumpAndSettle();
      expect(start.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('visual choices and static names expose screen-reader actions', (
    tester,
  ) async {
    final settings = await _settings(tester);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(_app(_flexibleGame(), settings));
    await tester.tap(find.byKey(const ValueKey('configure-participants')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('2 players'), findsOneWidget);
    expect(find.bySemanticsLabel('3 players'), findsOneWidget);
    expect(find.bySemanticsLabel('4 players'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('3 players'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Player 1 setup'), findsOneWidget);
    expect(find.bySemanticsLabel('Mint color'), findsOneWidget);
    expect(find.bySemanticsLabel('Circle token'), findsOneWidget);
    expect(find.bySemanticsLabel('Local human player'), findsWidgets);

    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.edit_rounded), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('four-player setup stays centered and bounded on a tablet', (
    tester,
  ) async {
    final settings = await _settings(tester);
    tester.view.physicalSize = const Size(1024, 768);

    await tester.pumpWidget(_app(_flexibleGame(), settings));
    await tester.tap(find.byKey(const ValueKey('configure-participants')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('participant-count-4')));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(ListView)).width, lessThanOrEqualTo(680));
    final fourthParticipant = find.bySemanticsLabel('Player 4 setup');
    await tester.scrollUntilVisible(fourthParticipant, 300);
    await tester.pumpAndSettle();
    expect(fourthParticipant, findsOneWidget);
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
    expect(find.text('Set Up 2–4 Players'), findsNothing);
    expect(find.text('Play Together'), findsNothing);
    expect(find.text('Play with Bot'), findsNothing);

    await tester.tap(find.text('Play Solo'));
    await tester.pumpAndSettle();

    expect(find.text('Solo started'), findsOneWidget);
    expect(startedOptions!.mode, PlayMode.solo);
    expect(startedOptions!.participants, hasLength(1));
    expect(startedOptions!.participants.single.kind, ParticipantKind.human);
    expect(tester.takeException(), isNull);
  });
}
