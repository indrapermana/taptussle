import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/solitaire/solitaire_model.dart';

void main() {
  group('Solitaire undo', () {
    test('restores exact stock and waste through draw and recycle actions', () {
      final ace = _card(SolitaireSuit.clubs, 1);
      final two = _card(SolitaireSuit.clubs, 2);
      final initial = _state(stock: [two, ace]);

      final drawnOnce = initial.drawOrRecycle().model;
      final drawnTwice = drawnOnce.drawOrRecycle().model;
      final recycled = drawnTwice.drawOrRecycle().model;

      expect(recycled.canUndo, isTrue);
      _expectSameState(recycled.undo(), drawnTwice);
      _expectSameState(recycled.undo().undo(), drawnOnce);
      final restored = recycled.undo().undo().undo();
      _expectSameState(restored, initial);
      expect(restored.canUndo, isFalse);
      expect(identical(restored.undo(), restored), isTrue);
    });

    test('restores moved sequences, hidden cards, score and move count', () {
      final hidden = _card(SolitaireSuit.clubs, 7);
      final queen = _card(SolitaireSuit.hearts, 12);
      final king = _card(SolitaireSuit.spades, 13);
      final initial = _state(
        tableau: _piles({
          0: [_down(hidden), _up(queen)],
          1: [_up(king)],
        }),
        score: 30,
        moveCount: 4,
      );

      final moved = initial
          .moveTableauToTableau(source: 0, cardIndex: 1, destination: 1)
          .model;
      expect(moved.tableau[0].single.isFaceUp, isTrue);
      expect(moved.score, 35);
      expect(moved.moveCount, 5);

      final undone = moved.undo();
      _expectSameState(undone, initial);
      expect(undone.tableau[0].first.isFaceUp, isFalse);
    });

    test('restores foundation transfers and a pre-win position', () {
      final foundations = {
        for (final suit in SolitaireSuit.values)
          suit: [
            for (final rank in SolitaireRank.values)
              if (suit != SolitaireSuit.spades || rank != SolitaireRank.king)
                SolitaireCard(suit, rank),
          ],
      };
      final king = _card(SolitaireSuit.spades, 13);
      final initial = _state(
        tableau: _piles({
          0: [_up(king)],
        }),
        foundations: foundations,
      );

      final won = initial.moveTableauToFoundation(0).model;
      expect(won.isComplete, isTrue);

      final undone = won.undo();
      _expectSameState(undone, initial);
      expect(undone.isComplete, isFalse);
      expect(undone.tableau[0].single.card, king);
    });

    test('invalid actions do not create undo history', () {
      final queen = _card(SolitaireSuit.hearts, 12);
      final initial = _state(waste: [queen]);

      final rejected = initial.moveWasteToTableau(0);

      expect(rejected.accepted, isFalse);
      expect(identical(rejected.model, initial), isTrue);
      expect(initial.canUndo, isFalse);
    });
  });

  group('Solitaire deterministic hints', () {
    test('prioritizes tableau foundation progress by stable pile order', () {
      final clubAce = _card(SolitaireSuit.clubs, 1);
      final heartAce = _card(SolitaireSuit.hearts, 1);
      final model = _state(
        waste: [heartAce],
        tableau: _piles({
          0: [_up(clubAce)],
        }),
      );

      const expected = SolitaireHint(
        type: SolitaireHintType.tableauToFoundation,
        source: 0,
      );
      expect(model.hint, expected);
      expect(model.hint, expected);
      expect(model.moveCount, 0);

      final applied = model.applyHint(expected);
      expect(applied.accepted, isTrue);
      expect(applied.model.foundations[SolitaireSuit.clubs], [clubAce]);
    });

    test('suggests a waste Ace before tableau building', () {
      final ace = _card(SolitaireSuit.hearts, 1);
      final queen = _card(SolitaireSuit.hearts, 12);
      final king = _card(SolitaireSuit.spades, 13);
      final model = _state(
        waste: [ace],
        tableau: _piles({
          0: [_up(queen)],
          1: [_up(king)],
        }),
      );

      expect(
        model.hint,
        const SolitaireHint(type: SolitaireHintType.wasteToFoundation),
      );
    });

    test('prioritizes a move that reveals a hidden tableau card', () {
      final hidden = _card(SolitaireSuit.clubs, 5);
      final queen = _card(SolitaireSuit.hearts, 12);
      final king = _card(SolitaireSuit.spades, 13);
      final wasteJack = _card(SolitaireSuit.clubs, 11);
      final model = _state(
        waste: [wasteJack],
        tableau: _piles({
          0: [_down(hidden), _up(queen)],
          1: [_up(king)],
        }),
      );

      expect(
        model.hint,
        const SolitaireHint(
          type: SolitaireHintType.tableauToTableau,
          source: 0,
          cardIndex: 1,
          destination: 1,
        ),
      );
    });

    test('suggests a legal waste placement before cycling stock', () {
      final queen = _card(SolitaireSuit.hearts, 12);
      final king = _card(SolitaireSuit.spades, 13);
      final stockCard = _card(SolitaireSuit.clubs, 4);
      final model = _state(
        stock: [stockCard],
        waste: [queen],
        tableau: _piles({
          2: [_up(king)],
        }),
      );

      expect(
        model.hint,
        const SolitaireHint(
          type: SolitaireHintType.wasteToTableau,
          destination: 2,
        ),
      );
    });

    test('suggests draw or recycle when no card move is available', () {
      final five = _card(SolitaireSuit.clubs, 5);
      final model = _state(stock: [five]);
      const expected = SolitaireHint(type: SolitaireHintType.drawOrRecycle);

      expect(model.hint, expected);
      final applied = model.applyHint(expected);
      expect(applied.accepted, isTrue);
      expect(applied.model.wasteTop, five);
    });

    test(
      'uses foundation rollback only when it is the remaining legal move',
      () {
        final heartAce = _card(SolitaireSuit.hearts, 1);
        final spadeTwo = _card(SolitaireSuit.spades, 2);
        final model = _state(
          tableau: _piles({
            3: [_up(spadeTwo)],
          }),
          foundations: {
            SolitaireSuit.hearts: [heartAce],
          },
        );

        expect(
          model.hint,
          const SolitaireHint(
            type: SolitaireHintType.foundationToTableau,
            destination: 3,
            suit: SolitaireSuit.hearts,
          ),
        );
      },
    );

    test('reports no move and ignores pointless King-to-empty transfers', () {
      final queen = _card(SolitaireSuit.hearts, 12);
      expect(
        _state(
          tableau: _piles({
            0: [_up(queen)],
          }),
        ).hint,
        isNull,
      );

      final king = _card(SolitaireSuit.spades, 13);
      expect(
        _state(
          tableau: _piles({
            0: [_up(king)],
          }),
        ).hint,
        isNull,
      );
    });
  });
}

void _expectSameState(SolitaireModel actual, SolitaireModel expected) {
  expect(actual.drawMode, expected.drawMode);
  expect(actual.stock, expected.stock);
  expect(actual.waste, expected.waste);
  expect(actual.tableau, expected.tableau);
  expect(actual.foundations, expected.foundations);
  expect(actual.moveCount, expected.moveCount);
  expect(actual.score, expected.score);
  expect(actual.isComplete, expected.isComplete);
}

SolitaireModel _state({
  SolitaireDrawMode drawMode = SolitaireDrawMode.drawOne,
  List<SolitaireCard> stock = const [],
  List<SolitaireCard> waste = const [],
  List<List<SolitaireTableauCard>>? tableau,
  Map<SolitaireSuit, List<SolitaireCard>> foundations = const {},
  int score = 0,
  int moveCount = 0,
}) => SolitaireModel.fromState(
  drawMode: drawMode,
  stock: stock,
  waste: waste,
  tableau: tableau ?? _piles({}),
  foundations: foundations,
  score: score,
  moveCount: moveCount,
);

List<List<SolitaireTableauCard>> _piles(
  Map<int, List<SolitaireTableauCard>> cards,
) => List.generate(7, (index) => cards[index] ?? <SolitaireTableauCard>[]);

SolitaireTableauCard _up(SolitaireCard card) =>
    SolitaireTableauCard(card, isFaceUp: true);

SolitaireTableauCard _down(SolitaireCard card) =>
    SolitaireTableauCard(card, isFaceUp: false);

SolitaireCard _card(SolitaireSuit suit, int rank) =>
    SolitaireCard(suit, SolitaireRank.values[rank - 1]);
