import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/solitaire/solitaire_controller.dart';
import 'package:tap_tussle/games/solitaire/solitaire_model.dart';

void main() {
  test('tap selection moves waste to tableau and supports undo', () {
    final queen = _card(SolitaireSuit.hearts, 12);
    final king = _card(SolitaireSuit.spades, 13);
    final controller = SolitaireController(
      initialModel: _state(
        waste: [queen],
        tableau: _piles({
          0: [_up(king)],
        }),
      ),
      animationDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    expect(controller.tapWaste(), SolitaireInteractionResult.selected);
    expect(controller.selection?.type, SolitaireSelectionType.waste);
    expect(controller.tapTableau(0), SolitaireInteractionResult.moved);
    expect(controller.model.tableau[0].last.card, queen);
    expect(controller.model.waste, isEmpty);
    expect(controller.undo(), isTrue);
    expect(controller.model.wasteTop, queen);
    expect(controller.model.tableau[0].single.card, king);
  });

  test('drag moves a face-up sequence and rejects malformed sources', () {
    final queen = _card(SolitaireSuit.hearts, 12);
    final jack = _card(SolitaireSuit.spades, 11);
    final king = _card(SolitaireSuit.clubs, 13);
    final controller = SolitaireController(
      initialModel: _state(
        tableau: _piles({
          0: [_up(queen), _up(jack)],
          1: [_up(king)],
        }),
      ),
      animationDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    expect(
      controller.dragTableauToTableau(source: 0, cardIndex: 0, destination: 1),
      SolitaireInteractionResult.moved,
    );
    expect(controller.model.tableau[1], hasLength(3));
    expect(
      controller.dragTableauToFoundation(-1),
      SolitaireInteractionResult.invalid,
    );
  });

  testWidgets('animation locks input for its configured duration', (
    tester,
  ) async {
    final ace = _card(SolitaireSuit.clubs, 1);
    final controller = SolitaireController(
      initialModel: _state(waste: [ace]),
      animationDuration: const Duration(milliseconds: 240),
    );

    controller.tapWaste();
    expect(
      controller.moveSelectionToFoundation(),
      SolitaireInteractionResult.moved,
    );
    expect(controller.isAnimating, isTrue);
    expect(controller.tapTableau(0), SolitaireInteractionResult.inputLocked);
    await tester.pump(const Duration(milliseconds: 239));
    expect(controller.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.isAnimating, isFalse);
    controller.dispose();
  });

  testWidgets('session pause freezes elapsed time and blocks interaction', (
    tester,
  ) async {
    var now = DateTime(2026);
    final session = MatchSession(options: MatchOptions.solo())..start();
    final controller = SolitaireController(
      session: session,
      initialModel: _state(stock: [_card(SolitaireSuit.clubs, 5)]),
      now: () => now,
      animationDuration: Duration.zero,
    );

    now = now.add(const Duration(seconds: 12));
    session.pause();
    expect(controller.elapsed, const Duration(seconds: 12));
    expect(controller.isPaused, isTrue);
    now = now.add(const Duration(seconds: 30));
    expect(controller.elapsed, const Duration(seconds: 12));
    expect(controller.drawOrRecycle(), SolitaireInteractionResult.inputLocked);

    session.resume();
    now = now.add(const Duration(seconds: 3));
    expect(controller.elapsed, const Duration(seconds: 15));
    controller.dispose();
    session.dispose();
  });

  test('requestHint is non-mutating and clears after the suggested action', () {
    final ace = _card(SolitaireSuit.hearts, 1);
    final controller = SolitaireController(
      initialModel: _state(waste: [ace]),
      animationDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    final hint = controller.requestHint();
    expect(
      hint,
      const SolitaireHint(type: SolitaireHintType.wasteToFoundation),
    );
    expect(controller.model.moveCount, 0);
    controller.tapWaste();
    expect(controller.shownHint, isNull);
    expect(
      controller.moveSelectionToFoundation(),
      SolitaireInteractionResult.moved,
    );
    expect(controller.model.foundations[SolitaireSuit.hearts], [ace]);
  });
}

SolitaireModel _state({
  List<SolitaireCard> stock = const [],
  List<SolitaireCard> waste = const [],
  List<List<SolitaireTableauCard>>? tableau,
}) => SolitaireModel.fromState(
  drawMode: SolitaireDrawMode.drawOne,
  stock: stock,
  waste: waste,
  tableau: tableau ?? _piles({}),
);

List<List<SolitaireTableauCard>> _piles(
  Map<int, List<SolitaireTableauCard>> cards,
) => List.generate(7, (index) => cards[index] ?? <SolitaireTableauCard>[]);

SolitaireTableauCard _up(SolitaireCard card) =>
    SolitaireTableauCard(card, isFaceUp: true);

SolitaireCard _card(SolitaireSuit suit, int rank) =>
    SolitaireCard(suit, SolitaireRank.values[rank - 1]);
