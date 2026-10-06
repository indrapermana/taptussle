enum CangkulanSuit { clubs, diamonds, hearts, spades }

enum CangkulanRank {
  two(2),
  three(3),
  four(4),
  five(5),
  six(6),
  seven(7),
  eight(8),
  nine(9),
  ten(10),
  jack(11),
  queen(12),
  king(13),
  ace(14);

  const CangkulanRank(this.strength);
  final int strength;
}

class CangkulanCard {
  const CangkulanCard(this.suit, this.rank);

  final CangkulanSuit suit;
  final CangkulanRank rank;

  @override
  bool operator ==(Object other) =>
      other is CangkulanCard && other.suit == suit && other.rank == rank;

  @override
  int get hashCode => Object.hash(suit, rank);
}

class CangkulanTrickPlay {
  const CangkulanTrickPlay({required this.player, required this.card});

  final int player;
  final CangkulanCard card;
}

class CangkulanCompletedTrick {
  CangkulanCompletedTrick({
    required this.leader,
    required this.requiredSuit,
    required List<CangkulanTrickPlay> plays,
    required List<int> skippedPlayers,
    required this.winner,
  }) : plays = List.unmodifiable(plays),
       skippedPlayers = List.unmodifiable(skippedPlayers);

  final int leader;
  final CangkulanSuit requiredSuit;
  final List<CangkulanTrickPlay> plays;
  final List<int> skippedPlayers;
  final int winner;
}

enum CangkulanActionStatus {
  accepted,
  invalidPlayer,
  wrongTurn,
  cardNotHeld,
  mustFollowSuit,
  mustPlayCard,
  noRequiredSuit,
  matchFinished,
}

class CangkulanTurnAction {
  CangkulanTurnAction({
    required this.player,
    this.playedCard,
    List<CangkulanCard> drawnCards = const [],
    this.skipped = false,
    this.completedTrick,
    this.wonMatch = false,
  }) : drawnCards = List.unmodifiable(drawnCards);

  final int player;
  final CangkulanCard? playedCard;
  final List<CangkulanCard> drawnCards;
  final bool skipped;
  final CangkulanCompletedTrick? completedTrick;
  final bool wonMatch;
}

class CangkulanActionResult {
  const CangkulanActionResult({
    required this.status,
    required this.model,
    this.action,
  });

  final CangkulanActionStatus status;
  final CangkulanModel model;
  final CangkulanTurnAction? action;

  bool get accepted => status == CangkulanActionStatus.accepted;
}

/// Immutable rules for the TapTussle Cangkulan variant.
///
/// The first draw-pile card is the next card drawn. Every trick proceeds
/// clockwise from its leader. A follower who cannot follow suit uses [cangkul],
/// which draws until it finds and plays the required suit or skips when the pile
/// runs out. Played trick cards are discarded after the trick is resolved.
class CangkulanModel {
  CangkulanModel._({
    required this.participantCount,
    required List<List<CangkulanCard>> hands,
    required List<CangkulanCard> drawPile,
    required this.currentPlayer,
    required this.trickLeader,
    required List<CangkulanTrickPlay> trickPlays,
    required List<int> skippedPlayers,
    required this.completedTrickCount,
    required this.lastCompletedTrick,
    required this.winner,
  }) : hands = List.unmodifiable(
         hands.map((hand) => List<CangkulanCard>.unmodifiable(hand)),
       ),
       drawPile = List.unmodifiable(drawPile),
       trickPlays = List.unmodifiable(trickPlays),
       skippedPlayers = List.unmodifiable(skippedPlayers) {
    _validateState();
  }

  factory CangkulanModel.newGame({
    required int participantCount,
    List<CangkulanCard>? deck,
    int startingPlayer = 0,
  }) {
    _validateParticipantCount(participantCount);
    _validatePlayer(startingPlayer, participantCount, 'startingPlayer');
    final cards = List<CangkulanCard>.of(deck ?? standardDeck());
    final standard = standardDeck().toSet();
    if (cards.length != standard.length ||
        cards.toSet().length != cards.length) {
      throw ArgumentError.value(deck, 'deck', 'Must contain 52 unique cards');
    }
    if (!cards.toSet().containsAll(standard)) {
      throw ArgumentError.value(
        deck,
        'deck',
        'Must be a standard 52-card deck',
      );
    }

    final hands = List.generate(participantCount, (_) => <CangkulanCard>[]);
    var cursor = 0;
    for (var round = 0; round < cardsPerPlayer; round++) {
      for (var offset = 0; offset < participantCount; offset++) {
        final player = (startingPlayer + offset) % participantCount;
        hands[player].add(cards[cursor++]);
      }
    }
    return CangkulanModel._(
      participantCount: participantCount,
      hands: hands,
      drawPile: cards.sublist(cursor),
      currentPlayer: startingPlayer,
      trickLeader: startingPlayer,
      trickPlays: const [],
      skippedPlayers: const [],
      completedTrickCount: 0,
      lastCompletedTrick: null,
      winner: null,
    );
  }

  factory CangkulanModel.fromState({
    required List<List<CangkulanCard>> hands,
    List<CangkulanCard> drawPile = const [],
    int currentPlayer = 0,
    int? trickLeader,
    List<CangkulanTrickPlay> trickPlays = const [],
    List<int> skippedPlayers = const [],
    int completedTrickCount = 0,
    CangkulanCompletedTrick? lastCompletedTrick,
    int? winner,
  }) => CangkulanModel._(
    participantCount: hands.length,
    hands: hands,
    drawPile: drawPile,
    currentPlayer: currentPlayer,
    trickLeader: trickLeader ?? currentPlayer,
    trickPlays: trickPlays,
    skippedPlayers: skippedPlayers,
    completedTrickCount: completedTrickCount,
    lastCompletedTrick: lastCompletedTrick,
    winner: winner,
  );

  static const int cardsPerPlayer = 7;
  static const int deckSize = 52;

  final int participantCount;
  final List<List<CangkulanCard>> hands;
  final List<CangkulanCard> drawPile;
  final int currentPlayer;
  final int trickLeader;
  final List<CangkulanTrickPlay> trickPlays;
  final List<int> skippedPlayers;
  final int completedTrickCount;
  final CangkulanCompletedTrick? lastCompletedTrick;
  final int? winner;

  bool get isFinished => winner != null;
  CangkulanSuit? get requiredSuit =>
      trickPlays.isEmpty ? null : trickPlays.first.card.suit;
  int get actionsInCurrentTrick => trickPlays.length + skippedPlayers.length;
  bool get mustCangkul =>
      !isFinished && requiredSuit != null && legalCards.isEmpty;

  List<CangkulanCard> get legalCards {
    if (isFinished) return const [];
    final hand = hands[currentPlayer];
    final suit = requiredSuit;
    if (suit == null) return List.unmodifiable(hand);
    return List.unmodifiable(hand.where((card) => card.suit == suit));
  }

  CangkulanActionResult playCard(int player, CangkulanCard card) {
    final validation = _validateActionPlayer(player);
    if (validation != null) return _rejected(validation);
    final hand = hands[player];
    if (!hand.contains(card)) {
      return _rejected(CangkulanActionStatus.cardNotHeld);
    }
    final suit = requiredSuit;
    if (suit != null && card.suit != suit) {
      return _rejected(CangkulanActionStatus.mustFollowSuit);
    }

    final nextHands = _mutableHands();
    nextHands[player].remove(card);
    return _finishAction(
      player: player,
      hands: nextHands,
      pile: drawPile,
      playedCard: card,
      drawnCards: const [],
      skipped: false,
    );
  }

  CangkulanActionResult cangkul(int player) {
    final validation = _validateActionPlayer(player);
    if (validation != null) return _rejected(validation);
    final suit = requiredSuit;
    if (suit == null) return _rejected(CangkulanActionStatus.noRequiredSuit);
    if (hands[player].any((card) => card.suit == suit)) {
      return _rejected(CangkulanActionStatus.mustPlayCard);
    }

    final nextHands = _mutableHands();
    final nextPile = List<CangkulanCard>.of(drawPile);
    final drawn = <CangkulanCard>[];
    CangkulanCard? played;
    while (nextPile.isNotEmpty) {
      final card = nextPile.removeAt(0);
      drawn.add(card);
      if (card.suit == suit) {
        played = card;
        break;
      }
      nextHands[player].add(card);
    }
    return _finishAction(
      player: player,
      hands: nextHands,
      pile: nextPile,
      playedCard: played,
      drawnCards: drawn,
      skipped: played == null,
    );
  }

  CangkulanActionResult _finishAction({
    required int player,
    required List<List<CangkulanCard>> hands,
    required List<CangkulanCard> pile,
    required CangkulanCard? playedCard,
    required List<CangkulanCard> drawnCards,
    required bool skipped,
  }) {
    final plays = List<CangkulanTrickPlay>.of(trickPlays);
    final skips = List<int>.of(skippedPlayers);
    if (playedCard != null) {
      plays.add(CangkulanTrickPlay(player: player, card: playedCard));
    } else {
      skips.add(player);
    }

    if (hands[player].isEmpty) {
      final model = CangkulanModel._(
        participantCount: participantCount,
        hands: hands,
        drawPile: pile,
        currentPlayer: player,
        trickLeader: trickLeader,
        trickPlays: plays,
        skippedPlayers: skips,
        completedTrickCount: completedTrickCount,
        lastCompletedTrick: lastCompletedTrick,
        winner: player,
      );
      return CangkulanActionResult(
        status: CangkulanActionStatus.accepted,
        model: model,
        action: CangkulanTurnAction(
          player: player,
          playedCard: playedCard,
          drawnCards: drawnCards,
          skipped: skipped,
          wonMatch: true,
        ),
      );
    }

    final actions = plays.length + skips.length;
    if (actions == participantCount) {
      final completed = _resolveTrick(plays, skips);
      final model = CangkulanModel._(
        participantCount: participantCount,
        hands: hands,
        drawPile: pile,
        currentPlayer: completed.winner,
        trickLeader: completed.winner,
        trickPlays: const [],
        skippedPlayers: const [],
        completedTrickCount: completedTrickCount + 1,
        lastCompletedTrick: completed,
        winner: null,
      );
      return CangkulanActionResult(
        status: CangkulanActionStatus.accepted,
        model: model,
        action: CangkulanTurnAction(
          player: player,
          playedCard: playedCard,
          drawnCards: drawnCards,
          skipped: skipped,
          completedTrick: completed,
        ),
      );
    }

    final model = CangkulanModel._(
      participantCount: participantCount,
      hands: hands,
      drawPile: pile,
      currentPlayer: (player + 1) % participantCount,
      trickLeader: trickLeader,
      trickPlays: plays,
      skippedPlayers: skips,
      completedTrickCount: completedTrickCount,
      lastCompletedTrick: lastCompletedTrick,
      winner: null,
    );
    return CangkulanActionResult(
      status: CangkulanActionStatus.accepted,
      model: model,
      action: CangkulanTurnAction(
        player: player,
        playedCard: playedCard,
        drawnCards: drawnCards,
        skipped: skipped,
      ),
    );
  }

  CangkulanCompletedTrick _resolveTrick(
    List<CangkulanTrickPlay> plays,
    List<int> skips,
  ) {
    if (plays.isEmpty) {
      throw StateError('A trick must retain its lead card');
    }
    final suit = plays.first.card.suit;
    var winningPlay = plays.first;
    for (final play in plays.skip(1)) {
      if (play.card.suit == suit &&
          play.card.rank.strength > winningPlay.card.rank.strength) {
        winningPlay = play;
      }
    }
    return CangkulanCompletedTrick(
      leader: trickLeader,
      requiredSuit: suit,
      plays: plays,
      skippedPlayers: skips,
      winner: winningPlay.player,
    );
  }

  CangkulanActionStatus? _validateActionPlayer(int player) {
    if (player < 0 || player >= participantCount) {
      return CangkulanActionStatus.invalidPlayer;
    }
    if (isFinished) return CangkulanActionStatus.matchFinished;
    if (player != currentPlayer) return CangkulanActionStatus.wrongTurn;
    return null;
  }

  CangkulanActionResult _rejected(CangkulanActionStatus status) =>
      CangkulanActionResult(status: status, model: this);

  List<List<CangkulanCard>> _mutableHands() =>
      hands.map((hand) => List<CangkulanCard>.of(hand)).toList();

  void _validateState() {
    _validateParticipantCount(participantCount);
    _validatePlayer(currentPlayer, participantCount, 'currentPlayer');
    _validatePlayer(trickLeader, participantCount, 'trickLeader');
    if (winner != null) _validatePlayer(winner!, participantCount, 'winner');
    if (completedTrickCount < 0) {
      throw ArgumentError.value(
        completedTrickCount,
        'completedTrickCount',
        'Cannot be negative',
      );
    }
    final actors = [
      ...trickPlays.map((play) => play.player),
      ...skippedPlayers,
    ];
    if (actors.length > participantCount ||
        (actors.length == participantCount && winner == null) ||
        actors.toSet().length != actors.length) {
      throw ArgumentError('Current trick participants must act at most once');
    }
    for (final player in actors) {
      _validatePlayer(player, participantCount, 'trick participant');
    }
    if (trickPlays.isEmpty && skippedPlayers.isNotEmpty) {
      throw ArgumentError('Players cannot skip before a lead card');
    }
    final suit = requiredSuit;
    if (suit != null && trickPlays.any((play) => play.card.suit != suit)) {
      throw ArgumentError('Every played card in a trick must follow suit');
    }
    final allCards = <CangkulanCard>[
      ...hands.expand((hand) => hand),
      ...drawPile,
      ...trickPlays.map((play) => play.card),
    ];
    if (allCards.toSet().length != allCards.length) {
      throw ArgumentError('A card cannot appear in more than one active pile');
    }
  }

  static List<CangkulanCard> standardDeck() => List.unmodifiable([
    for (final suit in CangkulanSuit.values)
      for (final rank in CangkulanRank.values) CangkulanCard(suit, rank),
  ]);

  static void _validateParticipantCount(int count) {
    if (count < 2 || count > 4) {
      throw ArgumentError.value(
        count,
        'participantCount',
        'Must be 2, 3, or 4',
      );
    }
  }

  static void _validatePlayer(int player, int count, String name) {
    if (player < 0 || player >= count) {
      throw ArgumentError.value(player, name, 'Must identify a participant');
    }
  }
}
