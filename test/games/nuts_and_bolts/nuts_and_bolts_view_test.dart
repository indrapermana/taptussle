import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/haptic_service.dart';
import 'package:tap_tussle/core/sound_service.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_controller.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_levels.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_view.dart';

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
  Future<void> preview() async => lightImpacts++;

  @override
  Future<void> paddleHit() async => mediumImpacts++;

  @override
  void setEnabled(bool value) {}
}

void main() {
  testWidgets('renders responsive accessible bolts with color symbols', (
    tester,
  ) async {
    final level = NutsAndBoltsLevelCatalog.level(
      NutsAndBoltsDifficulty.easy,
      1,
    );
    final controller = NutsAndBoltsController(level: level);
    addTearDown(controller.dispose);

    await _pumpBoard(tester, controller, const Size(340, 600));
    expect(find.byKey(const ValueKey('nuts-bolts-board')), findsOneWidget);
    expect(find.byKey(const ValueKey('nuts-bolts-bolt-0')), findsOneWidget);
    expect(
      find.byKey(ValueKey('nuts-bolts-bolt-${level.bolts.length - 1}')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('bottom to top')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('empty')), findsNWidgets(2));
    expect(find.text('●'), findsWidgets);
    expect(find.text('▲'), findsWidgets);
    expect(find.byKey(const ValueKey('nuts-bolts-undo')), findsOneWidget);
    expect(find.byKey(const ValueKey('nuts-bolts-restart')), findsOneWidget);
    expect(find.byKey(const ValueKey('nuts-bolts-hint')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpBoard(tester, controller, const Size(1024, 768));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows selection, legal targets, hint, animation, and controls', (
    tester,
  ) async {
    final level = NutsAndBoltsLevelCatalog.level(
      NutsAndBoltsDifficulty.easy,
      1,
    );
    final controller = NutsAndBoltsController(
      level: level,
      animationDuration: const Duration(milliseconds: 100),
    );
    addTearDown(controller.dispose);
    await _pumpBoard(tester, controller, const Size(430, 760));

    await tester.tap(find.byKey(const ValueKey('nuts-bolts-hint')));
    await tester.pump();
    final hint = controller.hintMove!;
    expect(find.textContaining('HINT: BOLT'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('hint source')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('hint destination')), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('nuts-bolts-bolt-${hint.source}')));
    await tester.pump();
    expect(find.text('CHOOSE A GLOWING BOLT'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('selected')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('legal destination')), findsWidgets);

    await tester.tap(
      find.byKey(ValueKey('nuts-bolts-bolt-${hint.destination}')),
    );
    await tester.pump();
    expect(find.text('MOVING NUT…'), findsOneWidget);
    expect(find.text('1 MOVES'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('CHOOSE A TOP NUT'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nuts-bolts-undo')));
    await tester.pump();
    expect(find.text('0 MOVES'), findsOneWidget);
    final nextHint = controller.requestHint()!;
    controller.tapBolt(nextHint.source);
    controller.tapBolt(nextHint.destination);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('nuts-bolts-restart')));
    await tester.pump();
    expect(find.text('0 MOVES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dense hard level fits compact phone and tablet layouts', (
    tester,
  ) async {
    final level = NutsAndBoltsLevelCatalog.level(
      NutsAndBoltsDifficulty.hard,
      60,
    );
    final controller = NutsAndBoltsController(level: level);
    addTearDown(controller.dispose);

    await _pumpBoard(tester, controller, const Size(340, 600));
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('nuts-bolts-bolt-${level.bolts.length - 1}')),
      180,
      scrollable: find.byType(Scrollable),
    );
    expect(
      find.byKey(ValueKey('nuts-bolts-bolt-${level.bolts.length - 1}')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await _pumpBoard(tester, controller, const Size(1024, 768));
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('nuts-bolts-bolt-${level.bolts.length - 1}')),
      180,
      scrollable: find.byType(Scrollable),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('hints, moves, and completion use shared effects', (
    tester,
  ) async {
    final sounds = _RecordingSoundPlayer();
    final haptics = _RecordingHapticPlayer();
    SoundEffects.configure(sounds);
    HapticEffects.configure(haptics);
    final level = NutsAndBoltsLevel(
      id: 'effects-01',
      difficulty: NutsAndBoltsDifficulty.easy,
      number: 1,
      capacity: 2,
      helperBoltCount: 1,
      bolts: const [
        [0, 0],
        [1],
        [1],
      ],
      minimumSolutionMoves: 1,
      branching: const NutsAndBoltsBranchingMetadata(
        initialLegalMoves: 2,
        mixedColorBoundaries: 0,
        exploredStates: 2,
      ),
    );
    final controller = NutsAndBoltsController(
      level: level,
      animationDuration: Duration.zero,
    );
    addTearDown(controller.dispose);
    await _pumpBoard(tester, controller, const Size(430, 760));

    await tester.tap(find.byKey(const ValueKey('nuts-bolts-hint')));
    await tester.pump();
    final hint = controller.hintMove!;
    await tester.tap(find.byKey(ValueKey('nuts-bolts-bolt-${hint.source}')));
    await tester.tap(
      find.byKey(ValueKey('nuts-bolts-bolt-${hint.destination}')),
    );
    await tester.pump();

    expect(
      sounds.played,
      containsAll([
        SoundEffect.collect,
        SoundEffect.uiTap,
        SoundEffect.metalSlide,
        SoundEffect.puzzleComplete,
      ]),
    );
    expect(haptics.lightImpacts, 1);
    expect(haptics.mediumImpacts, 1);
  });
}

Future<void> _pumpBoard(
  WidgetTester tester,
  NutsAndBoltsController controller,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTapTussleTheme(),
      home: Scaffold(body: NutsAndBoltsBoard(controller: controller)),
    ),
  );
  await tester.pump();
}
