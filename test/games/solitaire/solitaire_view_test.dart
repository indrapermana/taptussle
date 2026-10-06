import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
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
    expect(find.bySemanticsLabel('Queen of hearts'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Tableau 2, 2 cards, 1 face down')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((widget) => widget is LongPressDraggable),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);

    await _pumpBoard(tester, controller, const Size(1024, 768));
    expect(tester.takeException(), isNull);
    controller.dispose();
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
    expect(find.text('CHOOSE A DESTINATION'), findsOneWidget);

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
    expect(find.textContaining('HINT:'), findsOneWidget);
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

List<List<SolitaireTableauCard>> _piles(
  Map<int, List<SolitaireTableauCard>> cards,
) => List.generate(7, (index) => cards[index] ?? <SolitaireTableauCard>[]);

Future<void> _pumpBoard(
  WidgetTester tester,
  SolitaireController controller,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTapTussleTheme(),
      home: Scaffold(body: SolitaireBoard(controller: controller)),
    ),
  );
  await tester.pump();
}
