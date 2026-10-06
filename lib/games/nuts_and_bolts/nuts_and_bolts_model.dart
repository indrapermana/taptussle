import 'dart:collection';

enum NutsAndBoltsMoveStatus {
  accepted,
  sameBolt,
  sourceOutOfRange,
  destinationOutOfRange,
  sourceEmpty,
  destinationFull,
  colorMismatch,
  puzzleCompleted,
}

class NutsAndBoltsMove {
  const NutsAndBoltsMove({
    required this.source,
    required this.destination,
    required this.color,
  });

  final int source;
  final int destination;
  final int color;

  @override
  bool operator ==(Object other) =>
      other is NutsAndBoltsMove &&
      source == other.source &&
      destination == other.destination &&
      color == other.color;

  @override
  int get hashCode => Object.hash(source, destination, color);
}

class NutsAndBoltsMoveResult {
  const NutsAndBoltsMoveResult({
    required this.status,
    required this.model,
    this.move,
  });

  final NutsAndBoltsMoveStatus status;
  final NutsAndBoltsModel model;
  final NutsAndBoltsMove? move;

  bool get accepted => status == NutsAndBoltsMoveStatus.accepted;
}

/// Immutable rules and state for a Nuts and Bolts puzzle.
///
/// Bolt contents are stored bottom-to-top. A move transfers exactly one exposed
/// top nut to an empty bolt or onto a nut of the same color, provided the
/// destination has capacity.
class NutsAndBoltsModel {
  factory NutsAndBoltsModel({
    required List<List<int>> bolts,
    int capacity = defaultBoltCapacity,
  }) {
    _validate(capacity, bolts);
    final initial = _freezeBolts(bolts);
    return NutsAndBoltsModel._(
      capacity: capacity,
      bolts: initial,
      initialBolts: initial,
      history: const [],
      moves: const [],
      moveCount: 0,
      lastMove: null,
    );
  }

  const NutsAndBoltsModel._({
    required this.capacity,
    required List<List<int>> bolts,
    required List<List<int>> initialBolts,
    required List<List<List<int>>> history,
    required List<NutsAndBoltsMove> moves,
    required this.moveCount,
    required this.lastMove,
  }) : _bolts = bolts,
       _initialBolts = initialBolts,
       _history = history,
       _moves = moves;

  factory NutsAndBoltsModel.restore({
    required List<List<int>> initialBolts,
    required Iterable<NutsAndBoltsMove> moves,
    int capacity = defaultBoltCapacity,
  }) {
    var model = NutsAndBoltsModel(bolts: initialBolts, capacity: capacity);
    for (final move in moves) {
      final result = model.move(move.source, move.destination);
      if (!result.accepted || result.move != move) {
        throw const FormatException(
          'Saved Nuts and Bolts move history is invalid',
        );
      }
      model = result.model;
    }
    return model;
  }

  static const int defaultBoltCapacity = 4;

  final int capacity;
  final List<List<int>> _bolts;
  final List<List<int>> _initialBolts;
  final List<List<List<int>>> _history;
  final List<NutsAndBoltsMove> _moves;
  final int moveCount;
  final NutsAndBoltsMove? lastMove;

  List<List<int>> get bolts => _bolts;
  int get boltCount => _bolts.length;
  bool get canUndo => _history.isNotEmpty;
  List<NutsAndBoltsMove> get moveHistory => _moves;

  bool get isComplete => _bolts.every(
    (bolt) =>
        bolt.isEmpty ||
        (bolt.length == capacity && bolt.every((color) => color == bolt.first)),
  );

  List<NutsAndBoltsMove> get legalMoves => List.unmodifiable([
    if (!isComplete)
      for (var source = 0; source < boltCount; source++)
        for (var destination = 0; destination < boltCount; destination++)
          if (_moveFor(source, destination) case final move?) move,
  ]);

  /// Returns one stable, immediately useful legal move without mutating state.
  /// Completing a stack ranks first, then matching-color stacks, then empty
  /// helpers. Source and destination indexes break ties deterministically.
  NutsAndBoltsMove? get hint {
    final candidates = legalMoves;
    if (candidates.isEmpty) return null;
    final ranked = candidates.toList()
      ..sort((left, right) {
        final scoreComparison = _hintScore(right).compareTo(_hintScore(left));
        if (scoreComparison != 0) return scoreComparison;
        final sourceComparison = left.source.compareTo(right.source);
        if (sourceComparison != 0) return sourceComparison;
        return left.destination.compareTo(right.destination);
      });
    return ranked.first;
  }

  bool canMove(int source, int destination) =>
      !isComplete && _moveFor(source, destination) != null;

  NutsAndBoltsMoveResult move(int source, int destination) {
    final invalidStatus = _invalidStatus(source, destination);
    if (invalidStatus != null) {
      return NutsAndBoltsMoveResult(status: invalidStatus, model: this);
    }

    final move = _moveFor(source, destination)!;
    final nextBolts = [for (final bolt in _bolts) List<int>.of(bolt)];
    nextBolts[source].removeLast();
    nextBolts[destination].add(move.color);

    final next = NutsAndBoltsModel._(
      capacity: capacity,
      bolts: _freezeBolts(nextBolts),
      initialBolts: _initialBolts,
      history: List.unmodifiable([..._history, _bolts]),
      moves: List.unmodifiable([..._moves, move]),
      moveCount: moveCount + 1,
      lastMove: move,
    );
    return NutsAndBoltsMoveResult(
      status: NutsAndBoltsMoveStatus.accepted,
      model: next,
      move: move,
    );
  }

  NutsAndBoltsModel undo() {
    if (!canUndo) return this;
    return NutsAndBoltsModel._(
      capacity: capacity,
      bolts: _history.last,
      initialBolts: _initialBolts,
      history: List.unmodifiable(_history.take(_history.length - 1)),
      moves: List.unmodifiable(_moves.take(_moves.length - 1)),
      moveCount: moveCount - 1,
      lastMove: null,
    );
  }

  NutsAndBoltsModel restart() {
    if (moveCount == 0) return this;
    return NutsAndBoltsModel._(
      capacity: capacity,
      bolts: _initialBolts,
      initialBolts: _initialBolts,
      history: const [],
      moves: const [],
      moveCount: 0,
      lastMove: null,
    );
  }

  NutsAndBoltsMoveStatus? _invalidStatus(int source, int destination) {
    if (source < 0 || source >= boltCount) {
      return NutsAndBoltsMoveStatus.sourceOutOfRange;
    }
    if (destination < 0 || destination >= boltCount) {
      return NutsAndBoltsMoveStatus.destinationOutOfRange;
    }
    if (source == destination) return NutsAndBoltsMoveStatus.sameBolt;
    if (isComplete) return NutsAndBoltsMoveStatus.puzzleCompleted;
    if (_bolts[source].isEmpty) return NutsAndBoltsMoveStatus.sourceEmpty;
    if (_bolts[destination].length == capacity) {
      return NutsAndBoltsMoveStatus.destinationFull;
    }
    if (_bolts[destination].isNotEmpty &&
        _bolts[destination].last != _bolts[source].last) {
      return NutsAndBoltsMoveStatus.colorMismatch;
    }
    return null;
  }

  NutsAndBoltsMove? _moveFor(int source, int destination) {
    if (source < 0 || source >= boltCount) return null;
    if (destination < 0 || destination >= boltCount) return null;
    if (source == destination || _bolts[source].isEmpty) return null;
    if (_bolts[destination].length == capacity) return null;
    final color = _bolts[source].last;
    if (_bolts[destination].isNotEmpty && _bolts[destination].last != color) {
      return null;
    }
    return NutsAndBoltsMove(
      source: source,
      destination: destination,
      color: color,
    );
  }

  int _hintScore(NutsAndBoltsMove move) {
    final destination = _bolts[move.destination];
    if (destination.length + 1 == capacity &&
        destination.every((color) => color == move.color)) {
      return 3;
    }
    if (destination.isNotEmpty) return 2;
    final source = _bolts[move.source];
    final sourceIsComplete =
        source.length == capacity &&
        source.every((color) => color == source.first);
    return sourceIsComplete ? 0 : 1;
  }

  static void _validate(int capacity, List<List<int>> bolts) {
    if (capacity < 2) {
      throw ArgumentError.value(capacity, 'capacity', 'Must be at least 2');
    }
    if (bolts.length < 2) {
      throw ArgumentError.value(
        bolts,
        'bolts',
        'Must contain at least 2 bolts',
      );
    }
    if (bolts.every((bolt) => bolt.isEmpty)) {
      throw ArgumentError.value(
        bolts,
        'bolts',
        'Must contain at least one nut',
      );
    }
    for (var index = 0; index < bolts.length; index++) {
      final bolt = bolts[index];
      if (bolt.length > capacity) {
        throw ArgumentError.value(
          bolt,
          'bolts[$index]',
          'Cannot exceed bolt capacity',
        );
      }
      if (bolt.any((color) => color < 0)) {
        throw ArgumentError.value(
          bolt,
          'bolts[$index]',
          'Color IDs cannot be negative',
        );
      }
    }
  }

  static List<List<int>> _freezeBolts(List<List<int>> bolts) =>
      UnmodifiableListView([
        for (final bolt in bolts) UnmodifiableListView(List<int>.of(bolt)),
      ]);
}
