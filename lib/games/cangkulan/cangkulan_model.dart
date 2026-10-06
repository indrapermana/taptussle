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

  @override
  bool operator ==(Object other) =>
      other is CangkulanTrickPlay &&
      other.player == player &&
      other.card == card;

  @override
  int get hashCode => Object.hash(player, card);
}

class CangkulanTrickTurn {
  CangkulanTrickTurn({
    required this.player,
    this.playedCard,
    List<CangkulanCard> drawnCards = const [],
    this.skipped = false,
  }) : drawnCards = List.unmodifiable(drawnCards) {
    if (skipped == (playedCard != null)) {
      throw ArgumentError(
        'A trick turn must either play one card or skip, but not both',
      );
    }
  }

  final int player;
  final CangkulanCard? playedCard;
  final List<CangkulanCard> drawnCards;
  final bool skipped;
}

class CangkulanCompletedTrick {
  CangkulanCompletedTrick({
    required this.leader,
    required this.requiredSuit,
    required List<CangkulanTrickTurn> turns,
    required this.winner,
  }) : turns = List.unmodifiable(turns);

  final int leader;
  final CangkulanSuit requiredSuit;
  final List<CangkulanTrickTurn> turns;
  final int winner;

  List<CangkulanTrickPlay> get plays => List.unmodifiable([
    for (final turn in turns)
      if (turn.playedCard != null)
        CangkulanTrickPlay(player: turn.player, card: turn.playedCard!),
  ]);
  List<int> get skippedPlayers => List.unmodifiable([
    for (final turn in turns)
      if (turn.skipped) turn.player,
  ]);
}

enum CangkulanLegalActionType { playCard, cangkul }

class CangkulanLegalAction {
  const CangkulanLegalAction.play(this.card)
    : type = CangkulanLegalActionType.playCard;
  const CangkulanLegalAction.cangkul()
    : type = CangkulanLegalActionType.cangkul,
      card = null;

  final CangkulanLegalActionType type;
  final CangkulanCard? card;

  @override
  bool operator ==(Object other) =>
      other is CangkulanLegalAction && other.type == type && other.card == card;

  @override
  int get hashCode => Object.hash(type, card);
}

class CangkulanMatchResult {
  CangkulanMatchResult({
    required this.winner,
    required List<int> remainingCards,
    required this.completedTricks,
    required this.remainingDrawCards,
  }) : remainingCards = List.unmodifiable(remainingCards);

  final int winner;
  final List<int> remainingCards;
  final int completedTricks;
  final int remainingDrawCards;
}

class CangkulanSnapshot {
  CangkulanSnapshot({
    required List<List<CangkulanCard>> hands,
    required List<CangkulanCard> drawPile,
    required this.currentPlayer,
    required this.trickLeader,
    required List<CangkulanTrickTurn> currentTrickTurns,
    required List<CangkulanCompletedTrick> completedTricks,
    required this.winner,
  }) : hands = List.unmodifiable(
         hands.map((hand) => List<CangkulanCard>.unmodifiable(hand)),
       ),
       drawPile = List.unmodifiable(drawPile),
       currentTrickTurns = List.unmodifiable(currentTrickTurns),
       completedTricks = List.unmodifiable(completedTricks);

  final List<List<CangkulanCard>> hands;
  final List<CangkulanCard> drawPile;
  final int currentPlayer;
  final int trickLeader;
  final List<CangkulanTrickTurn> currentTrickTurns;
  final List<CangkulanCompletedTrick> completedTricks;
  final int? winner;
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
    required List<CangkulanTrickTurn> currentTrickTurns,
    required List<CangkulanCompletedTrick> completedTricks,
    required this.winner,
  }) : hands = List.unmodifiable(
         hands.map((hand) => List<CangkulanCard>.unmodifiable(hand)),
       ),
       drawPile = List.unmodifiable(drawPile),
       currentTrickTurns = List.unmodifiable(currentTrickTurns),
       completedTricks = List.unmodifiable(completedTricks) {
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
      currentTrickTurns: const [],
      completedTricks: const [],
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
    List<CangkulanTrickTurn>? currentTrickTurns,
    List<CangkulanCompletedTrick> completedTricks = const [],
    int? winner,
  }) => CangkulanModel._(
    participantCount: hands.length,
    hands: hands,
    drawPile: drawPile,
    currentPlayer: currentPlayer,
    trickLeader: trickLeader ?? currentPlayer,
    currentTrickTurns: _restoreTurns(
      currentTrickTurns,
      trickPlays,
      skippedPlayers,
    ),
    completedTricks: completedTricks,
    winner: winner,
  );

  factory CangkulanModel.restore(CangkulanSnapshot snapshot) =>
      CangkulanModel._(
        participantCount: snapshot.hands.length,
        hands: snapshot.hands,
        drawPile: snapshot.drawPile,
        currentPlayer: snapshot.currentPlayer,
        trickLeader: snapshot.trickLeader,
        currentTrickTurns: snapshot.currentTrickTurns,
        completedTricks: snapshot.completedTricks,
        winner: snapshot.winner,
      );

  static const int cardsPerPlayer = 7;
  static const int deckSize = 52;

  final int participantCount;
  final List<List<CangkulanCard>> hands;
  final List<CangkulanCard> drawPile;
  final int currentPlayer;
  final int trickLeader;
  final List<CangkulanTrickTurn> currentTrickTurns;
  final List<CangkulanCompletedTrick> completedTricks;
  final int? winner;

  bool get isFinished => winner != null;
  int get completedTrickCount => completedTricks.length;
  CangkulanCompletedTrick? get lastCompletedTrick => completedTricks.lastOrNull;
  List<CangkulanTrickPlay> get trickPlays => List.unmodifiable([
    for (final turn in currentTrickTurns)
      if (turn.playedCard != null)
        CangkulanTrickPlay(player: turn.player, card: turn.playedCard!),
  ]);
  List<int> get skippedPlayers => List.unmodifiable([
    for (final turn in currentTrickTurns)
      if (turn.skipped) turn.player,
  ]);
  CangkulanSuit? get requiredSuit =>
      trickPlays.isEmpty ? null : trickPlays.first.card.suit;
  int get actionsInCurrentTrick => currentTrickTurns.length;
  bool get mustCangkul =>
      !isFinished && requiredSuit != null && legalCards.isEmpty;

  List<CangkulanCard> get legalCards {
    if (isFinished) return const [];
    final hand = hands[currentPlayer];
    final suit = requiredSuit;
    if (suit == null) return List.unmodifiable(hand);
    return List.unmodifiable(hand.where((card) => card.suit == suit));
  }

  List<CangkulanLegalAction> get legalActions {
    if (isFinished) return const [];
    final cards = legalCards;
    if (cards.isNotEmpty) {
      return List.unmodifiable(cards.map(CangkulanLegalAction.play));
    }
    return mustCangkul ? const [CangkulanLegalAction.cangkul()] : const [];
  }

  CangkulanMatchResult? get matchResult => winner == null
      ? null
      : CangkulanMatchResult(
          winner: winner!,
          remainingCards: hands.map((hand) => hand.length).toList(),
          completedTricks: completedTrickCount,
          remainingDrawCards: drawPile.length,
        );

  CangkulanSnapshot get snapshot => CangkulanSnapshot(
    hands: hands,
    drawPile: drawPile,
    currentPlayer: currentPlayer,
    trickLeader: trickLeader,
    currentTrickTurns: currentTrickTurns,
    completedTricks: completedTricks,
    winner: winner,
  );

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

  CangkulanActionResult performAction(
    int player,
    CangkulanLegalAction action,
  ) => switch (action.type) {
    CangkulanLegalActionType.playCard => playCard(player, action.card!),
    CangkulanLegalActionType.cangkul => cangkul(player),
  };

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
    final turn = CangkulanTrickTurn(
      player: player,
      playedCard: playedCard,
      drawnCards: drawnCards,
      skipped: skipped,
    );
    final turns = [...currentTrickTurns, turn];

    if (hands[player].isEmpty) {
      final model = CangkulanModel._(
        participantCount: participantCount,
        hands: hands,
        drawPile: pile,
        currentPlayer: player,
        trickLeader: trickLeader,
        currentTrickTurns: turns,
        completedTricks: completedTricks,
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

    if (turns.length == participantCount) {
      final completed = _resolveTrick(turns);
      final model = CangkulanModel._(
        participantCount: participantCount,
        hands: hands,
        drawPile: pile,
        currentPlayer: completed.winner,
        trickLeader: completed.winner,
        currentTrickTurns: const [],
        completedTricks: [...completedTricks, completed],
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
      currentTrickTurns: turns,
      completedTricks: completedTricks,
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

  CangkulanCompletedTrick _resolveTrick(List<CangkulanTrickTurn> turns) {
    final plays = [
      for (final turn in turns)
        if (turn.playedCard != null)
          CangkulanTrickPlay(player: turn.player, card: turn.playedCard!),
    ];
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
      turns: turns,
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
    final actors = currentTrickTurns.map((turn) => turn.player).toList();
    if (actors.length > participantCount ||
        (actors.length == participantCount && winner == null) ||
        actors.toSet().length != actors.length) {
      throw ArgumentError('Current trick participants must act at most once');
    }
    for (final player in actors) {
      _validatePlayer(player, participantCount, 'trick participant');
    }
    if (currentTrickTurns.isNotEmpty &&
        currentTrickTurns.first.playedCard == null) {
      throw ArgumentError('Players cannot skip before a lead card');
    }
    for (var index = 0; index < currentTrickTurns.length; index++) {
      final expected = (trickLeader + index) % participantCount;
      if (currentTrickTurns[index].player != expected) {
        throw ArgumentError('Current trick turns must follow clockwise order');
      }
    }
    if (currentTrickTurns.isEmpty && currentPlayer != trickLeader) {
      throw ArgumentError('A new trick must begin with its leader');
    }
    if (currentTrickTurns.isNotEmpty && winner == null) {
      final expected = (currentTrickTurns.last.player + 1) % participantCount;
      if (currentPlayer != expected) {
        throw ArgumentError('Current player must follow the previous turn');
      }
    }
    final suit = requiredSuit;
    if (suit != null && trickPlays.any((play) => play.card.suit != suit)) {
      throw ArgumentError('Every played card in a trick must follow suit');
    }
    for (final turn in currentTrickTurns) {
      _validateDrawMetadata(turn, suit!);
    }
    for (var index = 0; index < completedTricks.length; index++) {
      final trick = completedTricks[index];
      _validateCompletedTrick(trick);
      if (index > 0 && trick.leader != completedTricks[index - 1].winner) {
        throw ArgumentError('Each completed trick must follow the prior winner');
      }
    }
    if (completedTricks.isNotEmpty &&
        trickLeader != completedTricks.last.winner) {
      throw ArgumentError('The prior trick winner must lead the current trick');
    }
    if (winner == null && hands.any((hand) => hand.isEmpty)) {
      throw ArgumentError('An empty hand must have ended the match');
    }
    if (winner != null && hands[winner!].isNotEmpty) {
      throw ArgumentError('The match winner must have an empty hand');
    }
    final allCards = <CangkulanCard>[
      ...hands.expand((hand) => hand),
      ...drawPile,
      ...trickPlays.map((play) => play.card),
      ...completedTricks.expand(
        (trick) => trick.plays.map((play) => play.card),
      ),
    ];
    final standard = standardDeck().toSet();
    if (allCards.any((card) => !standard.contains(card)) ||
        allCards.toSet().length != allCards.length) {
      throw ArgumentError('Every tracked card must be unique and standard');
    }
  }

  void _validateCompletedTrick(CangkulanCompletedTrick trick) {
    _validatePlayer(trick.leader, participantCount, 'completed trick leader');
    _validatePlayer(trick.winner, participantCount, 'completed trick winner');
    if (trick.turns.length != participantCount) {
      throw ArgumentError('A completed trick must contain every participant');
    }
    for (var index = 0; index < trick.turns.length; index++) {
      final turn = trick.turns[index];
      final expected = (trick.leader + index) % participantCount;
      if (turn.player != expected) {
        throw ArgumentError(
          'Completed trick turns must follow clockwise order',
        );
      }
    }
    final plays = trick.plays;
    if (plays.isEmpty ||
        plays.first.player != trick.leader ||
        plays.any((play) => play.card.suit != trick.requiredSuit)) {
      throw ArgumentError('Completed trick cards must follow the lead suit');
    }
    final strongest = plays.reduce(
      (best, play) =>
          play.card.rank.strength > best.card.rank.strength ? play : best,
    );
    if (strongest.player != trick.winner) {
      throw ArgumentError('Completed trick winner must hold its highest card');
    }
    for (final turn in trick.turns) {
      _validateDrawMetadata(turn, trick.requiredSuit);
    }
  }

  void _validateDrawMetadata(
    CangkulanTrickTurn turn,
    CangkulanSuit requiredSuit,
  ) {
    if (turn.drawnCards.isEmpty) return;
    final matchingIndexes = <int>[
      for (var index = 0; index < turn.drawnCards.length; index++)
        if (turn.drawnCards[index].suit == requiredSuit) index,
    ];
    if (turn.skipped && matchingIndexes.isNotEmpty) {
      throw ArgumentError('A skipped cangkul turn cannot draw the required suit');
    }
    if (!turn.skipped &&
        (matchingIndexes.length != 1 ||
            matchingIndexes.single != turn.drawnCards.length - 1 ||
            turn.playedCard != turn.drawnCards.last)) {
      throw ArgumentError(
        'Cangkul must stop and play at the first required-suit card',
      );
    }
  }

  static List<CangkulanTrickTurn> _legacyTurns(
    List<CangkulanTrickPlay> plays,
    List<int> skippedPlayers,
  ) => List.unmodifiable([
    ...plays.map(
      (play) => CangkulanTrickTurn(player: play.player, playedCard: play.card),
    ),
    ...skippedPlayers.map(
      (player) => CangkulanTrickTurn(player: player, skipped: true),
    ),
  ]);

  static List<CangkulanTrickTurn> _restoreTurns(
    List<CangkulanTrickTurn>? turns,
    List<CangkulanTrickPlay> plays,
    List<int> skippedPlayers,
  ) {
    if (turns != null && (plays.isNotEmpty || skippedPlayers.isNotEmpty)) {
      throw ArgumentError(
        'Provide currentTrickTurns or legacy trick plays, not both',
      );
    }
    return turns ?? _legacyTurns(plays, skippedPlayers);
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
