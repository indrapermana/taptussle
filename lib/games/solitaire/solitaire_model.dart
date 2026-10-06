import 'dart:collection';
import 'dart:math';

enum SolitaireSuit { clubs, diamonds, hearts, spades }

enum SolitaireRank {
  ace(1),
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
  king(13);

  const SolitaireRank(this.value);

  final int value;
}

enum SolitaireCardColor { red, black }

enum SolitaireDrawMode {
  drawOne(1),
  drawThree(3);

  const SolitaireDrawMode(this.count);

  final int count;
}

enum SolitaireDifficulty {
  easy(SolitaireDrawMode.drawOne),
  normal(SolitaireDrawMode.drawOne),
  hard(SolitaireDrawMode.drawThree);

  const SolitaireDifficulty(this.drawMode);

  final SolitaireDrawMode drawMode;
}

enum SolitaireMoveStatus {
  accepted,
  matchFinished,
  stockAndWasteEmpty,
  sourceEmpty,
  sourceOutOfRange,
  destinationOutOfRange,
  cardFaceDown,
  invalidSequence,
  illegalDestination,
}

enum SolitaireHintType {
  drawOrRecycle,
  wasteToTableau,
  wasteToFoundation,
  tableauToTableau,
  tableauToFoundation,
  foundationToTableau,
}

typedef SolitaireDeckShuffler = void Function(List<SolitaireCard> deck);

class SolitaireCard {
  const SolitaireCard(this.suit, this.rank);

  final SolitaireSuit suit;
  final SolitaireRank rank;

  SolitaireCardColor get color => switch (suit) {
    SolitaireSuit.diamonds || SolitaireSuit.hearts => SolitaireCardColor.red,
    SolitaireSuit.clubs || SolitaireSuit.spades => SolitaireCardColor.black,
  };

  @override
  bool operator ==(Object other) =>
      other is SolitaireCard && suit == other.suit && rank == other.rank;

  @override
  int get hashCode => Object.hash(suit, rank);

  @override
  String toString() => '${rank.name} of ${suit.name}';
}

class SolitaireTableauCard {
  const SolitaireTableauCard(this.card, {required this.isFaceUp});

  final SolitaireCard card;
  final bool isFaceUp;

  SolitaireTableauCard flippedUp() =>
      isFaceUp ? this : SolitaireTableauCard(card, isFaceUp: true);

  @override
  bool operator ==(Object other) =>
      other is SolitaireTableauCard &&
      card == other.card &&
      isFaceUp == other.isFaceUp;

  @override
  int get hashCode => Object.hash(card, isFaceUp);
}

class SolitaireHint {
  const SolitaireHint({
    required this.type,
    this.source,
    this.cardIndex,
    this.destination,
    this.suit,
  });

  final SolitaireHintType type;
  final int? source;
  final int? cardIndex;
  final int? destination;
  final SolitaireSuit? suit;

  @override
  bool operator ==(Object other) =>
      other is SolitaireHint &&
      type == other.type &&
      source == other.source &&
      cardIndex == other.cardIndex &&
      destination == other.destination &&
      suit == other.suit;

  @override
  int get hashCode => Object.hash(type, source, cardIndex, destination, suit);
}

class SolitaireMoveResult {
  const SolitaireMoveResult({
    required this.status,
    required this.model,
    this.movedCards = const [],
    this.flippedCard,
  });

  final SolitaireMoveStatus status;
  final SolitaireModel model;
  final List<SolitaireCard> movedCards;
  final SolitaireCard? flippedCard;

  bool get accepted => status == SolitaireMoveStatus.accepted;
}

class SolitaireStateSnapshot {
  SolitaireStateSnapshot({
    required List<SolitaireCard> stock,
    required List<SolitaireCard> waste,
    required List<List<SolitaireTableauCard>> tableau,
    required Map<SolitaireSuit, List<SolitaireCard>> foundations,
    required this.moveCount,
    required this.score,
  }) : stock = List.unmodifiable(stock),
       waste = List.unmodifiable(waste),
       tableau = List.unmodifiable(
         tableau.map((pile) => List<SolitaireTableauCard>.unmodifiable(pile)),
       ),
       foundations = Map.unmodifiable({
         for (final suit in SolitaireSuit.values)
           suit: List<SolitaireCard>.unmodifiable(
             foundations[suit] ?? const [],
           ),
       });

  final List<SolitaireCard> stock;
  final List<SolitaireCard> waste;
  final List<List<SolitaireTableauCard>> tableau;
  final Map<SolitaireSuit, List<SolitaireCard>> foundations;
  final int moveCount;
  final int score;
}

/// Immutable Klondike rules and state, independent from Flutter rendering.
///
/// Piles are stored bottom-to-top, so the last element is always playable.
/// A supplied [shuffle] makes a new game deterministic for tests and saved
/// deals. Stock recycling is unlimited and preserves the original pass order.
class SolitaireModel {
  factory SolitaireModel.newGame({
    SolitaireDrawMode drawMode = SolitaireDrawMode.drawOne,
    SolitaireDeckShuffler? shuffle,
  }) {
    final deck = List<SolitaireCard>.of(standardDeck());
    if (shuffle == null) {
      deck.shuffle();
    } else {
      shuffle(deck);
    }
    return SolitaireModel.fromDeck(deck: deck, drawMode: drawMode);
  }

  factory SolitaireModel.fromDeck({
    required List<SolitaireCard> deck,
    SolitaireDrawMode drawMode = SolitaireDrawMode.drawOne,
  }) {
    _validateFullDeck(deck);
    final tableau = List.generate(7, (_) => <SolitaireTableauCard>[]);
    var cursor = 0;
    for (var column = 0; column < tableau.length; column++) {
      for (var row = 0; row <= column; row++) {
        tableau[column].add(
          SolitaireTableauCard(deck[cursor++], isFaceUp: row == column),
        );
      }
    }
    return SolitaireModel._(
      drawMode: drawMode,
      stock: deck.sublist(cursor).reversed.toList(),
      waste: const [],
      tableau: tableau,
      foundations: const {},
      moveCount: 0,
      score: 0,
      history: const [],
    );
  }

  factory SolitaireModel.fromState({
    required SolitaireDrawMode drawMode,
    List<SolitaireCard> stock = const [],
    List<SolitaireCard> waste = const [],
    required List<List<SolitaireTableauCard>> tableau,
    Map<SolitaireSuit, List<SolitaireCard>> foundations = const {},
    int moveCount = 0,
    int score = 0,
  }) {
    if (tableau.length != tableauPileCount) {
      throw ArgumentError.value(
        tableau.length,
        'tableau',
        'Klondike requires seven tableau piles',
      );
    }
    if (moveCount < 0) {
      throw ArgumentError.value(moveCount, 'moveCount', 'Cannot be negative');
    }
    _validateState(stock, waste, tableau, foundations);
    return SolitaireModel._(
      drawMode: drawMode,
      stock: stock,
      waste: waste,
      tableau: tableau,
      foundations: foundations,
      moveCount: moveCount,
      score: score,
      history: const [],
    );
  }

  factory SolitaireModel.restore({
    required SolitaireDrawMode drawMode,
    required List<SolitaireStateSnapshot> snapshots,
  }) {
    if (snapshots.isEmpty) {
      throw ArgumentError.value(snapshots, 'snapshots', 'Cannot be empty');
    }
    Set<SolitaireCard>? expectedCards;
    for (var index = 0; index < snapshots.length; index++) {
      final snapshot = snapshots[index];
      if (snapshot.moveCount < 0 || snapshot.score < 0) {
        throw const FormatException('Saved counters cannot be negative');
      }
      _validateState(
        snapshot.stock,
        snapshot.waste,
        snapshot.tableau,
        snapshot.foundations,
      );
      final cards = _cardsIn(
        snapshot.stock,
        snapshot.waste,
        snapshot.tableau,
        snapshot.foundations,
      ).toSet();
      expectedCards ??= cards;
      if (expectedCards.length != cards.length ||
          !expectedCards.containsAll(cards)) {
        throw const FormatException('Saved states must contain the same cards');
      }
      if (index > 0 &&
          snapshot.moveCount != snapshots[index - 1].moveCount + 1) {
        throw const FormatException('Saved move counts must be consecutive');
      }
    }
    final current = snapshots.last;
    return SolitaireModel._(
      drawMode: drawMode,
      stock: current.stock,
      waste: current.waste,
      tableau: current.tableau,
      foundations: current.foundations,
      moveCount: current.moveCount,
      score: current.score,
      history: snapshots.take(snapshots.length - 1).toList(),
    );
  }

  SolitaireModel._({
    required this.drawMode,
    required List<SolitaireCard> stock,
    required List<SolitaireCard> waste,
    required List<List<SolitaireTableauCard>> tableau,
    required Map<SolitaireSuit, List<SolitaireCard>> foundations,
    required this.moveCount,
    required this.score,
    required List<SolitaireStateSnapshot> history,
  }) : _stock = List.unmodifiable(stock),
       _waste = List.unmodifiable(waste),
       _tableau = List.unmodifiable(
         tableau.map((pile) => List<SolitaireTableauCard>.unmodifiable(pile)),
       ),
       _foundations = Map.unmodifiable({
         for (final suit in SolitaireSuit.values)
           suit: List<SolitaireCard>.unmodifiable(
             foundations[suit] ?? const [],
           ),
       }),
       _history = List.unmodifiable(history);

  static const int tableauPileCount = 7;
  static const int scoreWasteToTableau = 5;
  static const int scoreCardToFoundation = 10;
  static const int scoreTableauFlip = 5;
  static const int scoreFoundationToTableau = -15;

  final SolitaireDrawMode drawMode;
  final List<SolitaireCard> _stock;
  final List<SolitaireCard> _waste;
  final List<List<SolitaireTableauCard>> _tableau;
  final Map<SolitaireSuit, List<SolitaireCard>> _foundations;
  final int moveCount;
  final int score;
  final List<SolitaireStateSnapshot> _history;

  UnmodifiableListView<SolitaireCard> get stock => UnmodifiableListView(_stock);
  UnmodifiableListView<SolitaireCard> get waste => UnmodifiableListView(_waste);
  List<List<SolitaireTableauCard>> get tableau => _tableau;
  Map<SolitaireSuit, List<SolitaireCard>> get foundations => _foundations;
  SolitaireCard? get wasteTop => _waste.lastOrNull;
  bool get canUndo => _history.isNotEmpty;
  List<SolitaireStateSnapshot> get snapshots => List.unmodifiable([
    ..._history,
    SolitaireStateSnapshot(
      stock: _stock,
      waste: _waste,
      tableau: _tableau,
      foundations: _foundations,
      moveCount: moveCount,
      score: score,
    ),
  ]);
  bool get isComplete =>
      _foundations.values.fold<int>(0, (sum, pile) => sum + pile.length) == 52;

  static List<SolitaireCard> standardDeck() => List.unmodifiable([
    for (final suit in SolitaireSuit.values)
      for (final rank in SolitaireRank.values) SolitaireCard(suit, rank),
  ]);

  /// Returns one stable useful action, or null when no legal action exists.
  /// Foundation progress ranks first, followed by exposing a hidden tableau
  /// card, other tableau building, stock cycling, and foundation rollback.
  SolitaireHint? get hint {
    for (var source = 0; source < tableauPileCount; source++) {
      final pile = _tableau[source];
      if (pile.isNotEmpty &&
          pile.last.isFaceUp &&
          _canPlaceOnFoundation(pile.last.card)) {
        return SolitaireHint(
          type: SolitaireHintType.tableauToFoundation,
          source: source,
        );
      }
    }
    if (wasteTop case final card? when _canPlaceOnFoundation(card)) {
      return const SolitaireHint(type: SolitaireHintType.wasteToFoundation);
    }

    final revealingMove = _firstTableauHint(requiresHiddenCard: true);
    if (revealingMove != null) return revealingMove;

    if (wasteTop case final card?) {
      for (var destination = 0; destination < tableauPileCount; destination++) {
        if (_canPlaceOnTableau(card, _tableau[destination])) {
          return SolitaireHint(
            type: SolitaireHintType.wasteToTableau,
            destination: destination,
          );
        }
      }
    }

    final tableauMove = _firstTableauHint(requiresHiddenCard: false);
    if (tableauMove != null) return tableauMove;

    if (_stock.isNotEmpty || _waste.isNotEmpty) {
      return const SolitaireHint(type: SolitaireHintType.drawOrRecycle);
    }

    for (final suit in SolitaireSuit.values) {
      final foundation = _foundations[suit]!;
      if (foundation.isEmpty) continue;
      for (var destination = 0; destination < tableauPileCount; destination++) {
        if (_canPlaceOnTableau(foundation.last, _tableau[destination])) {
          return SolitaireHint(
            type: SolitaireHintType.foundationToTableau,
            destination: destination,
            suit: suit,
          );
        }
      }
    }
    return null;
  }

  SolitaireMoveResult applyHint(SolitaireHint suggested) =>
      switch (suggested.type) {
        SolitaireHintType.drawOrRecycle => drawOrRecycle(),
        SolitaireHintType.wasteToTableau => moveWasteToTableau(
          suggested.destination ?? -1,
        ),
        SolitaireHintType.wasteToFoundation => moveWasteToFoundation(),
        SolitaireHintType.tableauToTableau => moveTableauToTableau(
          source: suggested.source ?? -1,
          cardIndex: suggested.cardIndex ?? -1,
          destination: suggested.destination ?? -1,
        ),
        SolitaireHintType.tableauToFoundation => moveTableauToFoundation(
          suggested.source ?? -1,
        ),
        SolitaireHintType.foundationToTableau => moveFoundationToTableau(
          suggested.suit ?? SolitaireSuit.clubs,
          suggested.destination ?? -1,
        ),
      };

  SolitaireModel undo() {
    if (!canUndo) return this;
    final previous = _history.last;
    return SolitaireModel._(
      drawMode: drawMode,
      stock: previous.stock,
      waste: previous.waste,
      tableau: previous.tableau,
      foundations: previous.foundations,
      moveCount: previous.moveCount,
      score: previous.score,
      history: _history.take(_history.length - 1).toList(),
    );
  }

  SolitaireMoveResult drawOrRecycle() {
    if (isComplete) return _rejected(SolitaireMoveStatus.matchFinished);
    if (_stock.isEmpty) {
      if (_waste.isEmpty) {
        return _rejected(SolitaireMoveStatus.stockAndWasteEmpty);
      }
      return _accepted(stock: _waste.reversed.toList(), waste: const []);
    }

    final stock = List<SolitaireCard>.of(_stock);
    final waste = List<SolitaireCard>.of(_waste);
    final drawn = <SolitaireCard>[];
    for (var index = 0; index < drawMode.count && stock.isNotEmpty; index++) {
      final card = stock.removeLast();
      waste.add(card);
      drawn.add(card);
    }
    return _accepted(stock: stock, waste: waste, movedCards: drawn);
  }

  SolitaireMoveResult moveWasteToTableau(int destination) {
    if (isComplete) return _rejected(SolitaireMoveStatus.matchFinished);
    if (!_isTableauIndex(destination)) {
      return _rejected(SolitaireMoveStatus.destinationOutOfRange);
    }
    final card = wasteTop;
    if (card == null) return _rejected(SolitaireMoveStatus.sourceEmpty);
    if (!_canPlaceOnTableau(card, _tableau[destination])) {
      return _rejected(SolitaireMoveStatus.illegalDestination);
    }
    final waste = List<SolitaireCard>.of(_waste)..removeLast();
    final tableau = _copyTableau();
    tableau[destination].add(SolitaireTableauCard(card, isFaceUp: true));
    return _accepted(
      waste: waste,
      tableau: tableau,
      scoreDelta: scoreWasteToTableau,
      movedCards: [card],
    );
  }

  SolitaireMoveResult moveWasteToFoundation() {
    if (isComplete) return _rejected(SolitaireMoveStatus.matchFinished);
    final card = wasteTop;
    if (card == null) return _rejected(SolitaireMoveStatus.sourceEmpty);
    if (!_canPlaceOnFoundation(card)) {
      return _rejected(SolitaireMoveStatus.illegalDestination);
    }
    final waste = List<SolitaireCard>.of(_waste)..removeLast();
    final foundations = _copyFoundations();
    foundations[card.suit]!.add(card);
    return _accepted(
      waste: waste,
      foundations: foundations,
      scoreDelta: scoreCardToFoundation,
      movedCards: [card],
    );
  }

  SolitaireMoveResult moveTableauToFoundation(int source) {
    if (isComplete) return _rejected(SolitaireMoveStatus.matchFinished);
    if (!_isTableauIndex(source)) {
      return _rejected(SolitaireMoveStatus.sourceOutOfRange);
    }
    if (_tableau[source].isEmpty) {
      return _rejected(SolitaireMoveStatus.sourceEmpty);
    }
    final exposed = _tableau[source].last;
    if (!exposed.isFaceUp) {
      return _rejected(SolitaireMoveStatus.cardFaceDown);
    }
    if (!_canPlaceOnFoundation(exposed.card)) {
      return _rejected(SolitaireMoveStatus.illegalDestination);
    }

    final tableau = _copyTableau();
    tableau[source].removeLast();
    final flipped = _flipExposedCard(tableau[source]);
    final foundations = _copyFoundations();
    foundations[exposed.card.suit]!.add(exposed.card);
    return _accepted(
      tableau: tableau,
      foundations: foundations,
      scoreDelta:
          scoreCardToFoundation + (flipped == null ? 0 : scoreTableauFlip),
      movedCards: [exposed.card],
      flippedCard: flipped,
    );
  }

  SolitaireMoveResult moveTableauToTableau({
    required int source,
    required int cardIndex,
    required int destination,
  }) {
    if (isComplete) return _rejected(SolitaireMoveStatus.matchFinished);
    if (!_isTableauIndex(source) || cardIndex < 0) {
      return _rejected(SolitaireMoveStatus.sourceOutOfRange);
    }
    if (!_isTableauIndex(destination)) {
      return _rejected(SolitaireMoveStatus.destinationOutOfRange);
    }
    if (source == destination) {
      return _rejected(SolitaireMoveStatus.illegalDestination);
    }
    final sourcePile = _tableau[source];
    if (sourcePile.isEmpty || cardIndex >= sourcePile.length) {
      return _rejected(SolitaireMoveStatus.sourceEmpty);
    }
    if (!sourcePile[cardIndex].isFaceUp) {
      return _rejected(SolitaireMoveStatus.cardFaceDown);
    }
    final moving = sourcePile.sublist(cardIndex);
    if (!_isValidFaceUpRun(moving)) {
      return _rejected(SolitaireMoveStatus.invalidSequence);
    }
    if (!_canPlaceOnTableau(moving.first.card, _tableau[destination])) {
      return _rejected(SolitaireMoveStatus.illegalDestination);
    }

    final tableau = _copyTableau();
    tableau[source].removeRange(cardIndex, tableau[source].length);
    final flipped = _flipExposedCard(tableau[source]);
    tableau[destination].addAll(moving);
    return _accepted(
      tableau: tableau,
      scoreDelta: flipped == null ? 0 : scoreTableauFlip,
      movedCards: moving.map((entry) => entry.card).toList(),
      flippedCard: flipped,
    );
  }

  SolitaireMoveResult moveFoundationToTableau(
    SolitaireSuit suit,
    int destination,
  ) {
    if (isComplete) return _rejected(SolitaireMoveStatus.matchFinished);
    if (!_isTableauIndex(destination)) {
      return _rejected(SolitaireMoveStatus.destinationOutOfRange);
    }
    final foundation = _foundations[suit]!;
    if (foundation.isEmpty) {
      return _rejected(SolitaireMoveStatus.sourceEmpty);
    }
    final card = foundation.last;
    if (!_canPlaceOnTableau(card, _tableau[destination])) {
      return _rejected(SolitaireMoveStatus.illegalDestination);
    }
    final foundations = _copyFoundations();
    foundations[suit]!.removeLast();
    final tableau = _copyTableau();
    tableau[destination].add(SolitaireTableauCard(card, isFaceUp: true));
    return _accepted(
      tableau: tableau,
      foundations: foundations,
      scoreDelta: scoreFoundationToTableau,
      movedCards: [card],
    );
  }

  bool _canPlaceOnFoundation(SolitaireCard card) {
    final pile = _foundations[card.suit]!;
    return card.rank.value == pile.length + 1;
  }

  static bool _canPlaceOnTableau(
    SolitaireCard card,
    List<SolitaireTableauCard> destination,
  ) {
    if (destination.isEmpty) return card.rank == SolitaireRank.king;
    final top = destination.last;
    return top.isFaceUp &&
        top.card.color != card.color &&
        top.card.rank.value == card.rank.value + 1;
  }

  static bool _isValidFaceUpRun(List<SolitaireTableauCard> cards) {
    for (var index = 0; index < cards.length; index++) {
      if (!cards[index].isFaceUp) return false;
      if (index > 0 &&
          !_canPlaceOnTableau(cards[index].card, [cards[index - 1]])) {
        return false;
      }
    }
    return true;
  }

  SolitaireCard? _flipExposedCard(List<SolitaireTableauCard> pile) {
    if (pile.isEmpty || pile.last.isFaceUp) return null;
    final card = pile.last.card;
    pile[pile.length - 1] = pile.last.flippedUp();
    return card;
  }

  SolitaireMoveResult _accepted({
    List<SolitaireCard>? stock,
    List<SolitaireCard>? waste,
    List<List<SolitaireTableauCard>>? tableau,
    Map<SolitaireSuit, List<SolitaireCard>>? foundations,
    int scoreDelta = 0,
    List<SolitaireCard> movedCards = const [],
    SolitaireCard? flippedCard,
  }) => SolitaireMoveResult(
    status: SolitaireMoveStatus.accepted,
    model: SolitaireModel._(
      drawMode: drawMode,
      stock: stock ?? _stock,
      waste: waste ?? _waste,
      tableau: tableau ?? _tableau,
      foundations: foundations ?? _foundations,
      moveCount: moveCount + 1,
      score: max(0, score + scoreDelta),
      history: [
        ..._history,
        SolitaireStateSnapshot(
          stock: _stock,
          waste: _waste,
          tableau: _tableau,
          foundations: _foundations,
          moveCount: moveCount,
          score: score,
        ),
      ],
    ),
    movedCards: List.unmodifiable(movedCards),
    flippedCard: flippedCard,
  );

  SolitaireMoveResult _rejected(SolitaireMoveStatus status) =>
      SolitaireMoveResult(status: status, model: this);

  List<List<SolitaireTableauCard>> _copyTableau() => [
    for (final pile in _tableau) List<SolitaireTableauCard>.of(pile),
  ];

  Map<SolitaireSuit, List<SolitaireCard>> _copyFoundations() => {
    for (final suit in SolitaireSuit.values)
      suit: List<SolitaireCard>.of(_foundations[suit]!),
  };

  SolitaireHint? _firstTableauHint({required bool requiresHiddenCard}) {
    for (var source = 0; source < tableauPileCount; source++) {
      final sourcePile = _tableau[source];
      final firstFaceUp = sourcePile.indexWhere((entry) => entry.isFaceUp);
      if (firstFaceUp < 0) continue;
      final revealsHidden = firstFaceUp > 0;
      if (requiresHiddenCard != revealsHidden) continue;
      for (
        var cardIndex = firstFaceUp;
        cardIndex < sourcePile.length;
        cardIndex++
      ) {
        final moving = sourcePile.sublist(cardIndex);
        if (!_isValidFaceUpRun(moving)) continue;
        for (
          var destination = 0;
          destination < tableauPileCount;
          destination++
        ) {
          if (destination == source) continue;
          if (_canPlaceOnTableau(moving.first.card, _tableau[destination])) {
            // Moving an exposed King between empty piles makes no progress.
            if (!revealsHidden &&
                moving.first.card.rank == SolitaireRank.king &&
                sourcePile.length == moving.length &&
                _tableau[destination].isEmpty) {
              continue;
            }
            return SolitaireHint(
              type: SolitaireHintType.tableauToTableau,
              source: source,
              cardIndex: cardIndex,
              destination: destination,
            );
          }
        }
      }
    }
    return null;
  }

  static bool _isTableauIndex(int index) =>
      index >= 0 && index < tableauPileCount;

  static void _validateFullDeck(List<SolitaireCard> deck) {
    if (deck.length != 52 || deck.toSet().length != 52) {
      throw ArgumentError.value(
        deck.length,
        'deck',
        'A deal requires 52 unique standard cards',
      );
    }
    final standard = standardDeck().toSet();
    if (!deck.every(standard.contains)) {
      throw ArgumentError.value(deck, 'deck', 'Contains a non-standard card');
    }
  }

  static void _validateState(
    List<SolitaireCard> stock,
    List<SolitaireCard> waste,
    List<List<SolitaireTableauCard>> tableau,
    Map<SolitaireSuit, List<SolitaireCard>> foundations,
  ) {
    final cards = _cardsIn(stock, waste, tableau, foundations);
    if (cards.length != cards.toSet().length) {
      throw ArgumentError.value(cards, 'state', 'Cards must be unique');
    }
    for (final entry in foundations.entries) {
      for (var index = 0; index < entry.value.length; index++) {
        final card = entry.value[index];
        if (card.suit != entry.key || card.rank.value != index + 1) {
          throw ArgumentError.value(
            entry.value,
            'foundations',
            'Foundations must build Ace to King in their own suit',
          );
        }
      }
    }
  }

  static List<SolitaireCard> _cardsIn(
    List<SolitaireCard> stock,
    List<SolitaireCard> waste,
    List<List<SolitaireTableauCard>> tableau,
    Map<SolitaireSuit, List<SolitaireCard>> foundations,
  ) => <SolitaireCard>[
    ...stock,
    ...waste,
    for (final pile in tableau)
      for (final entry in pile) entry.card,
    for (final pile in foundations.values) ...pile,
  ];
}
