import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/haptic_service.dart';
import 'package:tap_tussle/core/sound_service.dart';
import 'package:tap_tussle/games/water_sort/water_sort_controller.dart';
import 'package:tap_tussle/games/water_sort/water_sort_levels.dart';
import 'package:tap_tussle/games/water_sort/water_sort_view.dart';

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
  testWidgets('renders accessible patterned tubes and responsive controls', (
    tester,
  ) async {
    final level = WaterSortLevelCatalog.level(WaterSortDifficulty.easy, 1);
    final controller = WaterSortController(
      level: level,
      animationDuration: const Duration(milliseconds: 100),
    );
    addTearDown(controller.dispose);
    await _pumpBoard(tester, controller, const Size(340, 600));

    expect(find.byKey(const ValueKey('water-sort-board')), findsOneWidget);
    expect(find.byKey(const ValueKey('water-sort-tube-0')), findsOneWidget);
    expect(
      find.byKey(ValueKey('water-sort-tube-${level.tubes.length - 1}')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('bottom to top')), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('empty')), findsNWidgets(2));
    expect(find.text('●'), findsWidgets);
    expect(find.text('▲'), findsWidgets);
    expect(find.byKey(const ValueKey('water-sort-undo')), findsOneWidget);
    expect(find.byKey(const ValueKey('water-sort-restart')), findsOneWidget);
    expect(find.byKey(const ValueKey('water-sort-hint')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpBoard(tester, controller, const Size(1024, 768));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selection, hint, pour animation, undo, and restart are visible',
    (tester) async {
      final level = WaterSortLevelCatalog.level(WaterSortDifficulty.easy, 1);
      final controller = WaterSortController(
        level: level,
        animationDuration: const Duration(milliseconds: 100),
      );
      addTearDown(controller.dispose);
      await _pumpBoard(tester, controller, const Size(430, 760));

      await tester.tap(find.byKey(const ValueKey('water-sort-hint')));
      await tester.pump();
      final hint = controller.hintMove!;
      expect(find.textContaining('HINT: TUBE'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('hint source')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('hint destination')), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('water-sort-tube-${hint.source}')));
      await tester.pump();
      expect(find.text('CHOOSE A DESTINATION'), findsOneWidget);
      await tester.tap(
        find.byKey(ValueKey('water-sort-tube-${hint.destination}')),
      );
      await tester.pump();
      expect(find.text('POURING…'), findsOneWidget);
      expect(find.text('1 MOVES'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('CHOOSE A TUBE'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('water-sort-undo')));
      await tester.pump();
      expect(find.text('0 MOVES'), findsOneWidget);
      final nextHint = controller.requestHint()!;
      controller.tapTube(nextHint.source);
      controller.tapTube(nextHint.destination);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('water-sort-restart')));
      await tester.pump();
      expect(find.text('0 MOVES'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pours, completion, hints, and controls use shared effects', (
    tester,
  ) async {
    final sounds = _RecordingSoundPlayer();
    final haptics = _RecordingHapticPlayer();
    SoundEffects.configure(sounds);
    HapticEffects.configure(haptics);
    final level = WaterSortLevel(
      id: 'effects-01',
      difficulty: WaterSortDifficulty.easy,
      number: 1,
      capacity: 2,
      helperTubeCount: 1,
      tubes: const [
        [0, 0],
        [1],
        [1],
      ],
      minimumSolutionMoves: 1,
      branching: const WaterSortBranchingMetadata(
        initialLegalMoves: 2,
        mixedColorBoundaries: 0,
      ),
    );
    final controller = WaterSortController(
      level: level,
      animationDuration: Duration.zero,
    );
    addTearDown(controller.dispose);
    await _pumpBoard(tester, controller, const Size(430, 760));

    await tester.tap(find.byKey(const ValueKey('water-sort-hint')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('water-sort-tube-1')));
    await tester.tap(find.byKey(const ValueKey('water-sort-tube-2')));
    await tester.pump();

    expect(
      sounds.played,
      containsAll([
        SoundEffect.collect,
        SoundEffect.uiTap,
        SoundEffect.liquidPour,
        SoundEffect.puzzleComplete,
      ]),
    );
    expect(haptics.lightImpacts, 1);
    expect(haptics.mediumImpacts, 1);
  });
}

Future<void> _pumpBoard(
  WidgetTester tester,
  WaterSortController controller,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTapTussleTheme(),
      home: Scaffold(body: WaterSortBoard(controller: controller)),
    ),
  );
  await tester.pump();
}
