import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/core/haptic_service.dart';
import 'package:tap_tussle/core/sound_service.dart';
import 'package:tap_tussle/games/solitaire/solitaire_controller.dart';
import 'package:tap_tussle/games/solitaire/solitaire_model.dart';
import 'package:tap_tussle/games/solitaire/solitaire_view.dart';

void main() {
  testWidgets('renders a readable responsive table on phone and tablet sizes', (
    tester,
  ) async {
    final controller = _controller();

    await _pumpBoard(tester, controller, const Size(350, 600));
    expect(find.byKey(const ValueKey('solitaire-stock')), findsOneWidget);
    expect(find.byKey(const ValueKey('solitaire-tableau')), findsOneWidget);
    expect(find.byKey(const ValueKey('solitaire-tableau-6')), findsOneWidget);
    expect(find.byKey(const ValueKey('solitaire-undo')), findsOneWidget);
    expect(find.byKey(const ValueKey('solitaire-hint')), findsOneWidget);
    expect(find.byKey(const ValueKey('solitaire-card-back-art')), findsWidgets);
    expect(find.byKey(const ValueKey('solitaire-court-queen')), findsOneWidget);
    expect(find.byKey(const ValueKey('solitaire-court-king')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('solitaire-center-suit-diamonds')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Queen of hearts'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Tableau 2, 2 cards, 1 face down')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((widget) => widget is LongPressDraggable),
      findsWidgets,
    );
    expect(find.byType(AnimatedSlide), findsWidgets);
    expect(tester.takeException(), isNull);

    await _pumpBoard(tester, controller, const Size(1024, 768));
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('uses the full width on an iPhone-sized portrait screen', (
    tester,
  ) async {
    final controller = _controller();
    await _pumpBoard(tester, controller, const Size(390, 844));

    final stockSize = tester.getSize(
      find.byKey(const ValueKey('solitaire-stock')),
    );
    final tableauRect = tester.getRect(
      find.byKey(const ValueKey('solitaire-tableau')),
    );

    expect(stockSize.width, greaterThan(52));
    expect(tableauRect.left, lessThanOrEqualTo(5));
    expect(390 - tableauRect.right, lessThanOrEqualTo(5));
    expect(find.text('BACK'), findsOneWidget);
    expect(find.text('HINT'), findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('small portrait supports 200 percent text without overflow', (
    tester,
  ) async {
    final controller = _controller();
    await _pumpBoard(
      tester,
      controller,
      const Size(390, 844),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.byKey(const ValueKey('solitaire-stock')), findsOneWidget);
    expect(find.byKey(const ValueKey('solitaire-tableau-6')), findsOneWidget);
    expect(find.byKey(const ValueKey('solitaire-undo')), findsOneWidget);
    expect(find.byKey(const ValueKey('solitaire-hint')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('solitaire-hint'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('portrait tablet preserves the board and accessible actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = _controller();
    await _pumpBoard(tester, controller, const Size(768, 1024));

    expect(find.bySemanticsLabel(RegExp(r'Stock, 1 cards')), findsOneWidget);
    expect(find.bySemanticsLabel('Queen of hearts'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Tableau 2, 2 cards')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('solitaire-tableau-6')), findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.dispose();
    semantics.dispose();
  });

  testWidgets('tap controls select, move, hint, and undo visibly', (
    tester,
  ) async {
    final controller = _controller();
    await _pumpBoard(tester, controller, const Size(430, 760));

    await tester.tap(
      find.byKey(const ValueKey('solitaire-waste-hearts-queen')),
    );
    await tester.pump();
    expect(find.text('PICK A GLOWING SPOT'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Tableau 1, 1 cards, 0 face down, legal destination',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('solitaire-tableau-1')));
    await tester.pump();
    expect(find.text('TRY A GLOWING SPOT'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('solitaire-waste-hearts-queen')),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('solitaire-tableau-0')));
    await tester.pump();
    expect(controller.model.tableau[0].last.card.rank, SolitaireRank.queen);
    expect(find.text('1 MOVES • 0:00'), findsOneWidget);

    await tester.pump(controller.animationDuration);
    await tester.tap(find.byKey(const ValueKey('solitaire-undo')));
    await tester.pump();
    expect(controller.model.moveCount, 0);
    expect(controller.model.wasteTop?.rank, SolitaireRank.queen);

    await tester.tap(find.byKey(const ValueKey('solitaire-hint')));
    await tester.pump();
    expect(find.textContaining('TRY THIS:'), findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('long-press drag moves a card to a legal tableau pile', (
    tester,
  ) async {
    final controller = _controller();
    await _pumpBoard(tester, controller, const Size(430, 760));

    final waste = find.byKey(const ValueKey('solitaire-waste-hearts-queen'));
    final destination = find.byKey(const ValueKey('solitaire-tableau-0'));
    final gesture = await tester.startGesture(tester.getCenter(waste));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveTo(tester.getCenter(destination));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(controller.model.waste, isEmpty);
    expect(controller.model.tableau[0].last.card.rank, SolitaireRank.queen);
    controller.dispose();
  });

  testWidgets('revealed tableau cards animate from back to face', (
    tester,
  ) async {
    final controller = SolitaireController(
      initialModel: _flipModel(),
      animationDuration: const Duration(milliseconds: 100),
    );
    await _pumpBoard(tester, controller, const Size(700, 390));

    expect(
      find.byKey(const ValueKey('solitaire-card-face-down')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('solitaire-tableau-0-card-1')));
    await tester.tap(find.byKey(const ValueKey('solitaire-tableau-1')));
    await tester.pump(const Duration(milliseconds: 20));

    expect(
      find.byKey(const ValueKey('solitaire-tableau-0-card-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('solitaire-card-face-down')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('solitaire-card-face-down')),
      findsNothing,
    );
    controller.dispose();
  });

  testWidgets('pause hides cards and resume restores the table', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.solo())..start();
    final controller = SolitaireController(
      session: session,
      initialModel: _model(),
      animationDuration: Duration.zero,
    );
    await _pumpBoard(tester, controller, const Size(430, 760));

    session.pause();
    await tester.pump();
    expect(find.byKey(const ValueKey('solitaire-paused')), findsOneWidget);
    expect(find.byKey(const ValueKey('solitaire-tableau')), findsNothing);

    session.resume();
    await tester.pump();
    expect(find.byKey(const ValueKey('solitaire-tableau')), findsOneWidget);
    controller.dispose();
    session.dispose();
  });

  testWidgets('draw, hint, move, completion, and invalid actions use effects', (
    tester,
  ) async {
    final sounds = _RecordingSoundPlayer();
    final haptics = _RecordingHapticPlayer();
    SoundEffects.configure(sounds);
    HapticEffects.configure(haptics);
    final controller = SolitaireController(
      initialModel: _almostCompleteModel(),
      animationDuration: Duration.zero,
    );
    addTearDown(controller.dispose);
    await _pumpBoard(tester, controller, const Size(430, 760));

    await tester.tap(find.byKey(const ValueKey('solitaire-hint')));
    await tester.tap(find.byKey(const ValueKey('solitaire-tableau-0-card-0')));
    await tester.tap(find.byKey(const ValueKey('solitaire-foundation-spades')));
    await tester.pump();

    expect(
      sounds.played,
      containsAll([
        SoundEffect.collect,
        SoundEffect.cardPlace,
        SoundEffect.puzzleComplete,
      ]),
    );
    expect(haptics.lightImpacts, greaterThanOrEqualTo(2));
    expect(haptics.mediumImpacts, 1);
    expect(
      find.byKey(const ValueKey('solitaire-completion-celebration')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Solitaire complete celebration'),
      findsOneWidget,
    );
    expect(find.text('YOU DID IT!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
  });
}

class _RecordingSoundPlayer implements SoundPlayer {
  final played = <SoundEffect>[];
  @override
  Future<void> play(SoundEffect effect) async => played.add(effect);
  @override
  void setVolume(double value) {}
}

class _RecordingHapticPlayer implements HapticPlayer {
  int lightImpacts = 0;
  int mediumImpacts = 0;
  @override
  Future<void> preview() async => lightImpacts++;
  @override
  Future<void> paddleHit() async => mediumImpacts++;
  @override
  void setEnabled(bool value) {}
}

SolitaireController _controller() => SolitaireController(
  initialModel: _model(),
  animationDuration: const Duration(milliseconds: 100),
);

SolitaireModel _model() => SolitaireModel.fromState(
  drawMode: SolitaireDrawMode.drawOne,
  stock: const [SolitaireCard(SolitaireSuit.clubs, SolitaireRank.five)],
  waste: const [SolitaireCard(SolitaireSuit.hearts, SolitaireRank.queen)],
  tableau: _piles({
    0: [
      const SolitaireTableauCard(
        SolitaireCard(SolitaireSuit.spades, SolitaireRank.king),
        isFaceUp: true,
      ),
    ],
    1: [
      const SolitaireTableauCard(
        SolitaireCard(SolitaireSuit.clubs, SolitaireRank.seven),
        isFaceUp: false,
      ),
      const SolitaireTableauCard(
        SolitaireCard(SolitaireSuit.diamonds, SolitaireRank.six),
        isFaceUp: true,
      ),
    ],
  }),
);

SolitaireModel _almostCompleteModel() => SolitaireModel.fromState(
  drawMode: SolitaireDrawMode.drawOne,
  tableau: _piles({
    0: [
      const SolitaireTableauCard(
        SolitaireCard(SolitaireSuit.spades, SolitaireRank.king),
        isFaceUp: true,
      ),
    ],
  }),
  foundations: {
    for (final suit in SolitaireSuit.values)
      suit: [
        for (final rank in SolitaireRank.values)
          if (suit != SolitaireSuit.spades || rank != SolitaireRank.king)
            SolitaireCard(suit, rank),
      ],
  },
);

SolitaireModel _flipModel() => SolitaireModel.fromState(
  drawMode: SolitaireDrawMode.drawOne,
  tableau: _piles({
    0: const [
      SolitaireTableauCard(
        SolitaireCard(SolitaireSuit.clubs, SolitaireRank.five),
        isFaceUp: false,
      ),
      SolitaireTableauCard(
        SolitaireCard(SolitaireSuit.hearts, SolitaireRank.queen),
        isFaceUp: true,
      ),
    ],
    1: const [
      SolitaireTableauCard(
        SolitaireCard(SolitaireSuit.spades, SolitaireRank.king),
        isFaceUp: true,
      ),
    ],
  }),
);

List<List<SolitaireTableauCard>> _piles(
  Map<int, List<SolitaireTableauCard>> cards,
) => List.generate(7, (index) => cards[index] ?? <SolitaireTableauCard>[]);

Future<void> _pumpBoard(
  WidgetTester tester,
  SolitaireController controller,
  Size size, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTapTussleTheme(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Scaffold(body: SolitaireBoard(controller: controller)),
      ),
    ),
  );
  await tester.pump();
}
