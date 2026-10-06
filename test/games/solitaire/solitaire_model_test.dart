import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/solitaire/solitaire_model.dart';

void main() {
  group('Solitaire cards and deal', () {
    test('creates 52 unique standard cards with correct colors', () {
      final deck = SolitaireModel.standardDeck();

      expect(deck, hasLength(52));
      expect(deck.toSet(), hasLength(52));
      expect(
        const SolitaireCard(SolitaireSuit.hearts, SolitaireRank.ace).color,
        SolitaireCardColor.red,
      );
      expect(
        const SolitaireCard(SolitaireSuit.spades, SolitaireRank.king).color,
        SolitaireCardColor.black,
      );
      expect(
        () => deck.add(_card(SolitaireSuit.clubs, 1)),
        throwsUnsupportedError,
      );
    });

    test('deals seven tableau piles and leaves 24 cards in stock', () {
      final deck = SolitaireModel.standardDeck();
      final model = SolitaireModel.fromDeck(deck: deck);

      expect(model.tableau.map((pile) => pile.length), [1, 2, 3, 4, 5, 6, 7]);
      for (final pile in model.tableau) {
        expect(pile.where((entry) => entry.isFaceUp), hasLength(1));
        expect(pile.last.isFaceUp, isTrue);
      }
      expect(model.stock, hasLength(24));
      expect(model.waste, isEmpty);
      expect(model.stock.last, deck[28]);
      expect(model.moveCount, 0);
      expect(model.score, 0);
    });

    test(
      'supports injected deterministic shuffling without retaining mutation',
      () {
        var calls = 0;
        final model = SolitaireModel.newGame(
          shuffle: (deck) {
            calls++;
            deck.setAll(0, deck.reversed.toList());
          },
        );

        expect(calls, 1);
        expect(
          model.tableau.first.single.card,
          SolitaireModel.standardDeck().last,
        );
      },
    );

    test('rejects incomplete and duplicate deal injection', () {
      expect(
        () => SolitaireModel.fromDeck(
          deck: SolitaireModel.standardDeck().take(51).toList(),
        ),
        throwsArgumentError,
      );
      final duplicate = SolitaireModel.standardDeck().toList();
      duplicate[51] = duplicate.first;
      expect(
        () => SolitaireModel.fromDeck(deck: duplicate),
        throwsArgumentError,
      );
    });
  });

  group('stock and waste', () {
    test('draw-one exposes one card and counts the action', () {
      final ace = _card(SolitaireSuit.clubs, 1);
      final two = _card(SolitaireSuit.clubs, 2);
      final model = _state(
        drawMode: SolitaireDrawMode.drawOne,
        stock: [two, ace],
      );

      final result = model.drawOrRecycle();

      expect(result.accepted, isTrue);
      expect(result.movedCards, [ace]);
      expect(result.model.stock, [two]);
      expect(result.model.waste, [ace]);
      expect(result.model.wasteTop, ace);
      expect(result.model.moveCount, 1);
      expect(model.stock, [two, ace]);
    });

    test('draw-three moves up to three cards in physical order', () {
      final ace = _card(SolitaireSuit.clubs, 1);
      final two = _card(SolitaireSuit.clubs, 2);
      final three = _card(SolitaireSuit.clubs, 3);
      final four = _card(SolitaireSuit.clubs, 4);
      var model = _state(
        drawMode: SolitaireDrawMode.drawThree,
        stock: [four, three, two, ace],
      );

      final first = model.drawOrRecycle();
      expect(first.movedCards, [ace, two, three]);
      expect(first.model.wasteTop, three);
      expect(first.model.stock, [four]);

      model = first.model;
      final second = model.drawOrRecycle();
      expect(second.movedCards, [four]);
      expect(second.model.stock, isEmpty);
      expect(second.model.waste, [ace, two, three, four]);
    });

    test(
      'recycles waste without a limit and preserves the next-pass order',
      () {
        final ace = _card(SolitaireSuit.clubs, 1);
        final two = _card(SolitaireSuit.clubs, 2);
        var model = _state(
          drawMode: SolitaireDrawMode.drawOne,
          stock: [two, ace],
        );

        model = model.drawOrRecycle().model;
        model = model.drawOrRecycle().model;
        expect(model.stock, isEmpty);
        expect(model.waste, [ace, two]);

        model = model.drawOrRecycle().model;
        expect(model.stock, [two, ace]);
        expect(model.waste, isEmpty);
        model = model.drawOrRecycle().model;
        expect(model.wasteTop, ace);

        model = model.drawOrRecycle().model;
        model = model.drawOrRecycle().model;
        expect(model.stock, [two, ace]);
      },
    );

    test('rejects drawing when both stock and waste are empty', () {
      final model = _state();
      final result = model.drawOrRecycle();

      expect(result.status, SolitaireMoveStatus.stockAndWasteEmpty);
      expect(identical(result.model, model), isTrue);
      expect(model.moveCount, 0);
    });
  });

  group('tableau moves', () {
    test('builds descending ranks with alternating colors', () {
      final redQueen = _card(SolitaireSuit.hearts, 12);
      final blackJack = _card(SolitaireSuit.spades, 11);
      final model = _state(
        tableau: _piles({
          0: [_up(redQueen)],
          1: [_up(blackJack)],
        }),
      );

      final result = model.moveTableauToTableau(
        source: 1,
        cardIndex: 0,
        destination: 0,
      );

      expect(result.accepted, isTrue);
      expect(result.movedCards, [blackJack]);
      expect(result.model.tableau[0].map((entry) => entry.card), [
        redQueen,
        blackJack,
      ]);
      expect(result.model.tableau[1], isEmpty);
    });

    test('moves a complete face-up sequence together', () {
      final redQueen = _card(SolitaireSuit.hearts, 12);
      final blackJack = _card(SolitaireSuit.spades, 11);
      final redTen = _card(SolitaireSuit.diamonds, 10);
      final blackKing = _card(SolitaireSuit.clubs, 13);
      final model = _state(
        tableau: _piles({
          0: [_up(redQueen), _up(blackJack), _up(redTen)],
          1: [_up(blackKing)],
        }),
      );

      final result = model.moveTableauToTableau(
        source: 0,
        cardIndex: 0,
        destination: 1,
      );

      expect(result.accepted, isTrue);
      expect(result.movedCards, [redQueen, blackJack, redTen]);
      expect(result.model.tableau[1], hasLength(4));
    });

    test('only places a King into an empty tableau pile', () {
      final king = _card(SolitaireSuit.hearts, 13);
      final queen = _card(SolitaireSuit.spades, 12);
      final model = _state(waste: [queen, king]);

      final kingMove = model.moveWasteToTableau(0);
      expect(kingMove.accepted, isTrue);
      expect(kingMove.model.score, SolitaireModel.scoreWasteToTableau);

      final queenOnly = _state(waste: [queen]);
      expect(
        queenOnly.moveWasteToTableau(0).status,
        SolitaireMoveStatus.illegalDestination,
      );
    });

    test(
      'rejects same-color, non-descending, face-down and malformed moves',
      () {
        final redQueen = _card(SolitaireSuit.hearts, 12);
        final redJack = _card(SolitaireSuit.diamonds, 11);
        final blackTen = _card(SolitaireSuit.clubs, 10);
        final model = _state(
          tableau: _piles({
            0: [_up(redQueen)],
            1: [_up(redJack)],
            2: [_down(blackTen)],
          }),
        );

        expect(
          model
              .moveTableauToTableau(source: 1, cardIndex: 0, destination: 0)
              .status,
          SolitaireMoveStatus.illegalDestination,
        );
        expect(
          model
              .moveTableauToTableau(source: 2, cardIndex: 0, destination: 0)
              .status,
          SolitaireMoveStatus.cardFaceDown,
        );
        expect(
          model
              .moveTableauToTableau(source: -1, cardIndex: 0, destination: 0)
              .status,
          SolitaireMoveStatus.sourceOutOfRange,
        );
        expect(
          model
              .moveTableauToTableau(source: 0, cardIndex: 0, destination: 7)
              .status,
          SolitaireMoveStatus.destinationOutOfRange,
        );
      },
    );

    test('automatically flips a newly exposed tableau card and scores it', () {
      final hidden = _card(SolitaireSuit.clubs, 7);
      final moving = _card(SolitaireSuit.hearts, 12);
      final destination = _card(SolitaireSuit.spades, 13);
      final model = _state(
        tableau: _piles({
          0: [_down(hidden), _up(moving)],
          1: [_up(destination)],
        }),
      );

      final result = model.moveTableauToTableau(
        source: 0,
        cardIndex: 1,
        destination: 1,
      );

      expect(result.accepted, isTrue);
      expect(result.flippedCard, hidden);
      expect(result.model.tableau[0].single.isFaceUp, isTrue);
      expect(result.model.score, SolitaireModel.scoreTableauFlip);
    });
  });

  group('foundations, scoring and completion', () {
    test('builds each foundation Ace through King in suit', () {
      final ace = _card(SolitaireSuit.hearts, 1);
      final two = _card(SolitaireSuit.hearts, 2);
      var model = _state(waste: [two, ace]);

      final first = model.moveWasteToFoundation();
      expect(first.accepted, isTrue);
      expect(first.model.foundations[SolitaireSuit.hearts], [ace]);
      expect(first.model.score, SolitaireModel.scoreCardToFoundation);

      model = first.model;
      final second = model.moveWasteToFoundation();
      expect(second.accepted, isTrue);
      expect(second.model.foundations[SolitaireSuit.hearts], [ace, two]);
      expect(second.model.score, 2 * SolitaireModel.scoreCardToFoundation);
    });

    test(
      'rejects skipped ranks and a card on the wrong foundation sequence',
      () {
        final two = _card(SolitaireSuit.hearts, 2);
        final model = _state(waste: [two]);

        expect(
          model.moveWasteToFoundation().status,
          SolitaireMoveStatus.illegalDestination,
        );
        expect(model.moveCount, 0);
      },
    );

    test('allows foundation cards back to a legal tableau destination', () {
      final heartAce = _card(SolitaireSuit.hearts, 1);
      final blackTwo = _card(SolitaireSuit.spades, 2);
      final model = _state(
        tableau: _piles({
          0: [_up(blackTwo)],
        }),
        foundations: {
          SolitaireSuit.hearts: [heartAce],
        },
        score: 20,
      );

      final result = model.moveFoundationToTableau(SolitaireSuit.hearts, 0);

      expect(result.accepted, isTrue);
      expect(result.model.tableau[0].last.card, heartAce);
      expect(result.model.foundations[SolitaireSuit.hearts], isEmpty);
      expect(result.model.score, 5);
    });

    test('completes when all 52 cards reach foundations', () {
      final foundations = {
        for (final suit in SolitaireSuit.values)
          suit: [
            for (final rank in SolitaireRank.values)
              if (suit != SolitaireSuit.spades || rank != SolitaireRank.king)
                SolitaireCard(suit, rank),
          ],
      };
      final spadeKing = _card(SolitaireSuit.spades, 13);
      final model = _state(
        tableau: _piles({
          0: [_up(spadeKing)],
        }),
        foundations: foundations,
      );

      final result = model.moveTableauToFoundation(0);

      expect(result.accepted, isTrue);
      expect(result.model.isComplete, isTrue);
      expect(result.model.foundations[SolitaireSuit.spades], hasLength(13));
      expect(
        result.model.drawOrRecycle().status,
        SolitaireMoveStatus.matchFinished,
      );
    });

    test('state collections are immutable and reject duplicate cards', () {
      final ace = _card(SolitaireSuit.clubs, 1);
      final model = _state(stock: [ace]);

      expect(() => model.stock.add(ace), throwsUnsupportedError);
      expect(() => model.tableau.add([]), throwsUnsupportedError);
      expect(() => model.tableau.first.add(_up(ace)), throwsUnsupportedError);
      expect(() => _state(stock: [ace], waste: [ace]), throwsArgumentError);
    });
  });
}

SolitaireModel _state({
  SolitaireDrawMode drawMode = SolitaireDrawMode.drawOne,
  List<SolitaireCard> stock = const [],
  List<SolitaireCard> waste = const [],
  List<List<SolitaireTableauCard>>? tableau,
  Map<SolitaireSuit, List<SolitaireCard>> foundations = const {},
  int score = 0,
}) => SolitaireModel.fromState(
  drawMode: drawMode,
  stock: stock,
  waste: waste,
  tableau: tableau ?? _piles({}),
  foundations: foundations,
  score: score,
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
