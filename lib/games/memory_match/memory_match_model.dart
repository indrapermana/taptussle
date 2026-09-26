import 'dart:math';

enum MemoryMatchDifficulty {
  easy(rows: 3, columns: 4, openingPreview: Duration(seconds: 3)),
  normal(rows: 4, columns: 4, openingPreview: Duration(milliseconds: 1500)),
  hard(rows: 4, columns: 6, openingPreview: Duration.zero);

  const MemoryMatchDifficulty({
    required this.rows,
    required this.columns,
    required this.openingPreview,
  });

  final int rows;
  final int columns;
  final Duration openingPreview;
  int get cardCount => rows * columns;
  int get pairCount => cardCount ~/ 2;
}

enum MemoryCardState { hidden, revealed, matched }

class MemoryMatchCard {
  const MemoryMatchCard({required this.pairId, required this.state});

  final int pairId;
  final MemoryCardState state;
}

enum MemorySelectionResult {
  firstCard,
  matched,
  mismatch,
  completed,
  invalidPlayer,
  outOfBounds,
  wrongTurn,
  unavailable,
  awaitingMismatchResolution,
  matchFinished,
}

/// Pure rules and state for solo and two-player Memory Match.
///
/// A completed pair attempt counts as one move. A matching player keeps the
/// turn; a mismatch remains visible until [resolveMismatch] passes the turn.
class MemoryMatchModel {
  MemoryMatchModel({
    this.difficulty = MemoryMatchDifficulty.normal,
    this.playerCount = 1,
    int startingPlayer = 0,
    Random? random,
  }) : _random = random ?? Random(),
       _startingPlayer = startingPlayer,
       _currentPlayer = startingPlayer,
       _scores = List<int>.filled(playerCount, 0) {
    if (playerCount < 1 || playerCount > 2) {
      throw ArgumentError.value(
        playerCount,
        'playerCount',
        'Memory Match supports one or two players',
      );
    }
    if (startingPlayer < 0 || startingPlayer >= playerCount) {
      throw ArgumentError.value(
        startingPlayer,
        'startingPlayer',
        'Must identify a configured player',
      );
    }
    _deal();
  }

  final MemoryMatchDifficulty difficulty;
  final int playerCount;
  final Random _random;
  final List<int> _scores;
  List<int> _deck = const [];
  final Set<int> _matchedCards = {};
  final List<int> _revealedCards = [];

  List<int> get deck => List.unmodifiable(_deck);
  List<int> get scores => List.unmodifiable(_scores);
  List<int> get revealedCards => List.unmodifiable(_revealedCards);
  int get cardCount => difficulty.cardCount;
  int get pairCount => difficulty.pairCount;
  Duration get openingPreviewDuration =>
      playerCount == 1 ? difficulty.openingPreview : Duration.zero;

  int _startingPlayer;
  int get startingPlayer => _startingPlayer;

  int _currentPlayer;
  int get currentPlayer => _currentPlayer;

  int _moveCount = 0;
  int get moveCount => _moveCount;
  int get matchedPairs => _matchedCards.length ~/ 2;
  bool get hasPendingMismatch =>
      _revealedCards.length == 2 &&
      _deck[_revealedCards[0]] != _deck[_revealedCards[1]];
  bool get isFinished => matchedPairs == pairCount;

  int? get winner {
    if (!isFinished || playerCount == 1 || isDraw) return null;
    return _scores[0] > _scores[1] ? 0 : 1;
  }

  bool get isDraw => isFinished && playerCount == 2 && _scores[0] == _scores[1];

  MemoryMatchCard cardAt(int index) {
    RangeError.checkValidIndex(index, _deck, 'index');
    final state = _matchedCards.contains(index)
        ? MemoryCardState.matched
        : _revealedCards.contains(index)
        ? MemoryCardState.revealed
        : MemoryCardState.hidden;
    return MemoryMatchCard(pairId: _deck[index], state: state);
  }

  MemorySelectionResult selectCard(int player, int index) {
    if (player < 0 || player >= playerCount) {
      return MemorySelectionResult.invalidPlayer;
    }
    if (index < 0 || index >= cardCount) {
      return MemorySelectionResult.outOfBounds;
    }
    if (isFinished) return MemorySelectionResult.matchFinished;
    if (hasPendingMismatch) {
      return MemorySelectionResult.awaitingMismatchResolution;
    }
    if (player != _currentPlayer) return MemorySelectionResult.wrongTurn;
    if (_matchedCards.contains(index) || _revealedCards.contains(index)) {
      return MemorySelectionResult.unavailable;
    }

    _revealedCards.add(index);
    if (_revealedCards.length == 1) return MemorySelectionResult.firstCard;

    _moveCount++;
    final first = _revealedCards[0];
    if (_deck[first] != _deck[index]) return MemorySelectionResult.mismatch;

    _matchedCards.addAll(_revealedCards);
    _revealedCards.clear();
    _scores[player]++;
    return isFinished
        ? MemorySelectionResult.completed
        : MemorySelectionResult.matched;
  }

  bool resolveMismatch() {
    if (!hasPendingMismatch) return false;
    _revealedCards.clear();
    if (playerCount == 2) _currentPlayer = 1 - _currentPlayer;
    return true;
  }

  /// Clears progress and deals again without changing the starting player.
  void reset() {
    _clearProgress();
    _deal();
  }

  /// Deals a fresh board and alternates the starter in two-player matches.
  void startRematch() {
    if (playerCount == 2) _startingPlayer = 1 - _startingPlayer;
    _clearProgress();
    _deal();
  }

  void _clearProgress() {
    _matchedCards.clear();
    _revealedCards.clear();
    _scores.fillRange(0, _scores.length, 0);
    _moveCount = 0;
    _currentPlayer = _startingPlayer;
  }

  void _deal() {
    final previous = _deck;
    final next = [
      for (var pair = 0; pair < pairCount; pair++) ...[pair, pair],
    ]..shuffle(_random);
    if (previous.isNotEmpty && _sameDeck(previous, next)) {
      next.add(next.removeAt(0));
    }
    _deck = next;
  }

  bool _sameDeck(List<int> first, List<int> second) {
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}
