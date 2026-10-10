typedef DiceRoller = int Function();

enum BoardTransitionType { none, ladder, snake }

class SnakesAndLaddersTurn {
  const SnakesAndLaddersTurn({
    required this.playerIndex,
    required this.roll,
    required this.startSquare,
    required this.attemptedSquare,
    required this.endSquare,
    required this.transitionType,
    required this.won,
    required this.nextPlayerIndex,
  });

  final int playerIndex;
  final int roll;
  final int startSquare;
  final int attemptedSquare;
  final int endSquare;
  final BoardTransitionType transitionType;
  final bool won;
  final int? nextPlayerIndex;

  bool get wasOversized => attemptedSquare > SnakesAndLaddersModel.finishSquare;
  bool get moved => endSquare != startSquare;
}

/// Pure rules and movement state for a two-to-four-player match.
class SnakesAndLaddersModel {
  SnakesAndLaddersModel({
    required this.playerCount,
    required DiceRoller diceRoller,
    this.startingPlayer = 0,
    Map<int, int> transitions = standardTransitions,
  }) : _diceRoller = diceRoller,
       _transitions = Map.unmodifiable(transitions),
       _positions = List.filled(playerCount, 0) {
    if (playerCount < 2 || playerCount > 4) {
      throw ArgumentError.value(playerCount, 'playerCount', 'Must be 2 to 4');
    }
    if (startingPlayer < 0 || startingPlayer >= playerCount) {
      throw ArgumentError.value(
        startingPlayer,
        'startingPlayer',
        'Must identify a participant',
      );
    }
    _validateTransitions(_transitions);
    _currentPlayer = startingPlayer;
  }

  static const int firstSquare = 1;
  static const int finishSquare = 64;

  /// The fixed TapTussle 8x8 board layout.
  static const Map<int, int> standardTransitions = {
    // Ladders.
    3: 16,
    8: 30,
    20: 39,
    27: 48,
    41: 60,
    // Snakes.
    18: 6,
    26: 10,
    37: 24,
    50: 34,
    61: 45,
  };

  /// Rows in visual bottom-to-top order, alternating direction.
  static final List<List<int>> serpentineRows = List<List<int>>.unmodifiable([
    for (var row = 0; row < 8; row++)
      List<int>.unmodifiable(
        row.isEven
            ? [for (var column = 1; column <= 8; column++) row * 8 + column]
            : [for (var column = 8; column >= 1; column--) row * 8 + column],
      ),
  ]);

  final int playerCount;
  final int startingPlayer;
  final DiceRoller _diceRoller;
  final Map<int, int> _transitions;
  final List<int> _positions;

  Map<int, int> get transitions => _transitions;
  List<int> get positions => List.unmodifiable(_positions);

  late int _currentPlayer;
  int get currentPlayer => _currentPlayer;

  int? _winner;
  int? get winner => _winner;
  bool get isFinished => _winner != null;

  SnakesAndLaddersTurn? _lastTurn;
  SnakesAndLaddersTurn? get lastTurn => _lastTurn;

  SnakesAndLaddersTurn rollTurn() {
    if (isFinished) {
      throw StateError('The match has already finished');
    }

    final roll = _diceRoller();
    if (roll < 1 || roll > 6) {
      throw StateError(
        'Dice roller returned $roll; expected a value from 1 to 6',
      );
    }

    final player = _currentPlayer;
    final start = _positions[player];
    final attempted = start + roll;
    var end = start;
    var transitionType = BoardTransitionType.none;

    if (attempted <= finishSquare) {
      end = _transitions[attempted] ?? attempted;
      if (end > attempted) {
        transitionType = BoardTransitionType.ladder;
      } else if (end < attempted) {
        transitionType = BoardTransitionType.snake;
      }
      _positions[player] = end;
    }

    final won = end == finishSquare;
    if (won) {
      _winner = player;
    } else if (roll != 6) {
      _currentPlayer = (player + 1) % playerCount;
    }

    return _lastTurn = SnakesAndLaddersTurn(
      playerIndex: player,
      roll: roll,
      startSquare: start,
      attemptedSquare: attempted,
      endSquare: end,
      transitionType: transitionType,
      won: won,
      nextPlayerIndex: won ? null : _currentPlayer,
    );
  }

  void reset() {
    _positions.fillRange(0, _positions.length, 0);
    _currentPlayer = startingPlayer;
    _winner = null;
    _lastTurn = null;
  }

  static void _validateTransitions(Map<int, int> transitions) {
    for (final entry in transitions.entries) {
      if (entry.key < firstSquare || entry.key >= finishSquare) {
        throw ArgumentError.value(
          entry.key,
          'transitions',
          'Invalid start square',
        );
      }
      if (entry.value < firstSquare || entry.value > finishSquare) {
        throw ArgumentError.value(
          entry.value,
          'transitions',
          'Invalid end square',
        );
      }
      if (entry.key == entry.value) {
        throw ArgumentError.value(entry, 'transitions', 'Must move the token');
      }
      if (transitions.containsKey(entry.value)) {
        throw ArgumentError.value(
          entry,
          'transitions',
          'A transition cannot lead directly to another transition',
        );
      }
    }
  }
}
