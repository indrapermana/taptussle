import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/cangkulan/cangkulan_model.dart';

void main() {
  group('deck and deal', () {
    test('standard deck contains every unique card with Ace high', () {
      final deck = CangkulanModel.standardDeck();

      expect(deck, hasLength(52));
      expect(deck.toSet(), hasLength(52));
      expect(CangkulanRank.ace.strength, 14);
      expect(CangkulanRank.two.strength, 2);
    });

    for (final players in [2, 3, 4]) {
      test('deals seven cards clockwise to $players players', () {
        final deck = CangkulanModel.standardDeck();
        final model = CangkulanModel.newGame(
          participantCount: players,
          deck: deck,
          startingPlayer: 1,
        );

        expect(model.hands, everyElement(hasLength(7)));
        expect(model.drawPile, hasLength(52 - players * 7));
        expect(model.currentPlayer, 1);
        expect(model.trickLeader, 1);
        for (var offset = 0; offset < players; offset++) {
          final player = (1 + offset) % players;
          expect(model.hands[player].first, deck[offset]);
          expect(model.hands[player][1], deck[players + offset]);
        }
      });
    }

    test('rejects unsupported player counts and malformed decks', () {
      expect(
        () => CangkulanModel.newGame(participantCount: 1),
        throwsArgumentError,
      );
      expect(
        () => CangkulanModel.newGame(
          participantCount: 2,
          deck: CangkulanModel.standardDeck().sublist(1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('play and trick progression', () {
    test('leader may play any card and followers must follow suit', () {
      final heartSeven = _card(CangkulanSuit.hearts, CangkulanRank.seven);
      final heartKing = _card(CangkulanSuit.hearts, CangkulanRank.king);
      final clubAce = _card(CangkulanSuit.clubs, CangkulanRank.ace);
      final model = _state([
        [heartSeven, clubAce],
        [heartKing, _card(CangkulanSuit.spades, CangkulanRank.two)],
      ]);

      final lead = model.playCard(0, heartSeven);
      expect(lead.accepted, isTrue);
      expect(lead.model.requiredSuit, CangkulanSuit.hearts);
      expect(lead.model.currentPlayer, 1);
      expect(lead.model.legalCards, [heartKing]);

      final offSuit = lead.model.playCard(1, lead.model.hands[1].last);
      expect(offSuit.status, CangkulanActionStatus.mustFollowSuit);
      expect(offSuit.model, same(lead.model));
      expect(
        lead.model.playCard(0, clubAce).status,
        CangkulanActionStatus.wrongTurn,
      );
    });

    test('turns move clockwise and highest required-suit card leads next', () {
      var model = _state([
        [_heart(7), _club(2)],
        [_heart(13), _club(3)],
        [_heart(14), _club(4)],
        [_heart(10), _club(5)],
      ]);

      model = model.playCard(0, _heart(7)).model;
      expect(model.currentPlayer, 1);
      model = model.playCard(1, _heart(13)).model;
      expect(model.currentPlayer, 2);
      model = model.playCard(2, _heart(14)).model;
      expect(model.currentPlayer, 3);
      final result = model.playCard(3, _heart(10));

      expect(result.action!.completedTrick!.winner, 2);
      expect(result.action!.completedTrick!.requiredSuit, CangkulanSuit.hearts);
      expect(result.model.currentPlayer, 2);
      expect(result.model.trickLeader, 2);
      expect(result.model.completedTrickCount, 1);
      expect(result.model.trickPlays, isEmpty);
    });

    test('only the lead suit competes when restoring a valid trick', () {
      final model = CangkulanModel.fromState(
        hands: [
          [_club(2)],
          [_club(3)],
          [_club(4)],
        ],
        currentPlayer: 2,
        trickLeader: 0,
        trickPlays: [
          CangkulanTrickPlay(player: 0, card: _heart(10)),
          CangkulanTrickPlay(player: 1, card: _heart(14)),
        ],
      );

      final result = model.cangkul(2);
      expect(result.action!.skipped, isTrue);
      expect(result.action!.completedTrick!.winner, 1);
    });

    test('playing the final hand card wins immediately before trick end', () {
      final winningCard = _heart(7);
      final model = _state([
        [winningCard],
        [_heart(14), _club(2)],
        [_heart(10), _club(3)],
      ]);

      final result = model.playCard(0, winningCard);

      expect(result.accepted, isTrue);
      expect(result.action!.wonMatch, isTrue);
      expect(result.model.winner, 0);
      expect(result.model.isFinished, isTrue);
      expect(
        result.model.playCard(0, winningCard).status,
        CangkulanActionStatus.matchFinished,
      );
    });
  });

  group('cangkul', () {
    test('draws repeatedly until required suit appears and plays it', () {
      var model = _state(
        [
          [_heart(7), _club(2)],
          [_club(4), _club(5)],
        ],
        drawPile: [_spade(2), _diamond(9), _heart(12), _spade(8)],
      );
      model = model.playCard(0, _heart(7)).model;

      final result = model.cangkul(1);

      expect(result.accepted, isTrue);
      expect(result.action!.drawnCards, [_spade(2), _diamond(9), _heart(12)]);
      expect(result.action!.playedCard, _heart(12));
      expect(result.action!.skipped, isFalse);
      expect(result.model.hands[1], [
        _club(4),
        _club(5),
        _spade(2),
        _diamond(9),
      ]);
      expect(result.model.drawPile, [_spade(8)]);
      expect(result.action!.completedTrick!.winner, 1);
      expect(result.model.currentPlayer, 1);
    });

    test('empty pile skips player for this trick and continues clockwise', () {
      var model = _state([
        [_heart(10), _club(2)],
        [_club(4), _club(5)],
        [_heart(8), _club(6)],
      ]);
      model = model.playCard(0, _heart(10)).model;

      final skipped = model.cangkul(1);
      expect(skipped.action!.skipped, isTrue);
      expect(skipped.model.currentPlayer, 2);
      final finished = skipped.model.playCard(2, _heart(8));

      expect(finished.action!.completedTrick!.skippedPlayers, [1]);
      expect(finished.action!.completedTrick!.winner, 0);
      expect(finished.model.currentPlayer, 0);
    });

    test('exhausts nonmatching pile into hand before skipping', () {
      var model = _state(
        [
          [_heart(10), _club(2)],
          [_club(4), _club(5)],
        ],
        drawPile: [_spade(2), _diamond(9)],
      );
      model = model.playCard(0, _heart(10)).model;

      final result = model.cangkul(1);

      expect(result.action!.skipped, isTrue);
      expect(result.action!.drawnCards, [_spade(2), _diamond(9)]);
      expect(result.model.drawPile, isEmpty);
      expect(result.model.hands[1], [
        _club(4),
        _club(5),
        _spade(2),
        _diamond(9),
      ]);
    });

    test('cannot cangkul while leading or while holding required suit', () {
      final model = _state([
        [_heart(7), _club(2)],
        [_heart(8), _club(3)],
      ]);
      expect(model.cangkul(0).status, CangkulanActionStatus.noRequiredSuit);
      final led = model.playCard(0, _heart(7)).model;
      expect(led.mustCangkul, isFalse);
      expect(led.cangkul(1).status, CangkulanActionStatus.mustPlayCard);
    });
  });

  test('state collections are immutable and duplicate cards are rejected', () {
    final model = _state([
      [_heart(7), _club(2)],
      [_heart(8), _club(3)],
    ]);

    expect(() => model.hands.add([]), throwsUnsupportedError);
    expect(() => model.hands[0].clear(), throwsUnsupportedError);
    expect(() => model.drawPile.add(_spade(2)), throwsUnsupportedError);
    expect(
      () => CangkulanModel.fromState(
        hands: [
          [_heart(7)],
          [_heart(7)],
        ],
      ),
      throwsArgumentError,
    );
  });
}

CangkulanModel _state(
  List<List<CangkulanCard>> hands, {
  List<CangkulanCard> drawPile = const [],
}) => CangkulanModel.fromState(hands: hands, drawPile: drawPile);

CangkulanCard _card(CangkulanSuit suit, CangkulanRank rank) =>
    CangkulanCard(suit, rank);
CangkulanCard _heart(int strength) =>
    _card(CangkulanSuit.hearts, _rank(strength));
CangkulanCard _club(int strength) =>
    _card(CangkulanSuit.clubs, _rank(strength));
CangkulanCard _spade(int strength) =>
    _card(CangkulanSuit.spades, _rank(strength));
CangkulanCard _diamond(int strength) =>
    _card(CangkulanSuit.diamonds, _rank(strength));
CangkulanRank _rank(int strength) =>
    CangkulanRank.values.singleWhere((rank) => rank.strength == strength);
