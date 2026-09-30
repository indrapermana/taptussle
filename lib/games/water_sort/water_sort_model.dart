import 'dart:collection';

enum WaterSortPourStatus {
  accepted,
  sameTube,
  sourceOutOfRange,
  destinationOutOfRange,
  sourceEmpty,
  destinationFull,
  colorMismatch,
  puzzleCompleted,
}

class WaterSortMove {
  const WaterSortMove({
    required this.source,
    required this.destination,
    required this.color,
    required this.amount,
  });

  final int source;
  final int destination;
  final int color;
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is WaterSortMove &&
      source == other.source &&
      destination == other.destination &&
      color == other.color &&
      amount == other.amount;

  @override
  int get hashCode => Object.hash(source, destination, color, amount);
}

class WaterSortPourResult {
  const WaterSortPourResult({
    required this.status,
    required this.model,
    this.move,
  });

  final WaterSortPourStatus status;
  final WaterSortModel model;
  final WaterSortMove? move;

  bool get accepted => status == WaterSortPourStatus.accepted;
}

/// Immutable rules and state for a Water Sort puzzle.
///
/// Tube contents are stored bottom-to-top. A legal pour moves as much of the
/// contiguous top-color group as the destination can hold. Empty tubes accept
/// every color; non-empty tubes only accept their current top color.
class WaterSortModel {
  factory WaterSortModel({
    required List<List<int>> tubes,
    int capacity = defaultTubeCapacity,
  }) {
    _validate(capacity, tubes);
    final initial = _freezeTubes(tubes);
    return WaterSortModel._(
      capacity: capacity,
      tubes: initial,
      initialTubes: initial,
      history: const [],
      moveCount: 0,
      lastMove: null,
    );
  }

  const WaterSortModel._({
    required this.capacity,
    required List<List<int>> tubes,
    required List<List<int>> initialTubes,
    required List<List<List<int>>> history,
    required this.moveCount,
    required this.lastMove,
  }) : _tubes = tubes,
       _initialTubes = initialTubes,
       _history = history;

  static const int defaultTubeCapacity = 4;

  final int capacity;
  final List<List<int>> _tubes;
  final List<List<int>> _initialTubes;
  final List<List<List<int>>> _history;
  final int moveCount;
  final WaterSortMove? lastMove;

  List<List<int>> get tubes => _tubes;
  int get tubeCount => _tubes.length;
  bool get canUndo => _history.isNotEmpty;

  bool get isComplete => _tubes.every(
    (tube) =>
        tube.isEmpty ||
        (tube.length == capacity && tube.every((color) => color == tube.first)),
  );

  List<WaterSortMove> get legalMoves => List.unmodifiable([
    if (!isComplete)
      for (var source = 0; source < tubeCount; source++)
        for (var destination = 0; destination < tubeCount; destination++)
          if (_moveFor(source, destination) case final move?) move,
  ]);

  bool canPour(int source, int destination) =>
      !isComplete && _moveFor(source, destination) != null;

  WaterSortPourResult pour(int source, int destination) {
    final invalidStatus = _invalidStatus(source, destination);
    if (invalidStatus != null) {
      return WaterSortPourResult(status: invalidStatus, model: this);
    }

    final move = _moveFor(source, destination)!;
    final nextTubes = [for (final tube in _tubes) List<int>.of(tube)];
    nextTubes[source].removeRange(
      nextTubes[source].length - move.amount,
      nextTubes[source].length,
    );
    nextTubes[destination].addAll(List.filled(move.amount, move.color));

    final next = WaterSortModel._(
      capacity: capacity,
      tubes: _freezeTubes(nextTubes),
      initialTubes: _initialTubes,
      history: List.unmodifiable([..._history, _tubes]),
      moveCount: moveCount + 1,
      lastMove: move,
    );
    return WaterSortPourResult(
      status: WaterSortPourStatus.accepted,
      model: next,
      move: move,
    );
  }

  WaterSortModel undo() {
    if (!canUndo) return this;
    return WaterSortModel._(
      capacity: capacity,
      tubes: _history.last,
      initialTubes: _initialTubes,
      history: List.unmodifiable(_history.take(_history.length - 1)),
      moveCount: moveCount - 1,
      lastMove: null,
    );
  }

  WaterSortModel restart() {
    if (moveCount == 0) return this;
    return WaterSortModel._(
      capacity: capacity,
      tubes: _initialTubes,
      initialTubes: _initialTubes,
      history: const [],
      moveCount: 0,
      lastMove: null,
    );
  }

  WaterSortPourStatus? _invalidStatus(int source, int destination) {
    if (source < 0 || source >= tubeCount) {
      return WaterSortPourStatus.sourceOutOfRange;
    }
    if (destination < 0 || destination >= tubeCount) {
      return WaterSortPourStatus.destinationOutOfRange;
    }
    if (source == destination) return WaterSortPourStatus.sameTube;
    if (isComplete) return WaterSortPourStatus.puzzleCompleted;
    if (_tubes[source].isEmpty) return WaterSortPourStatus.sourceEmpty;
    if (_tubes[destination].length == capacity) {
      return WaterSortPourStatus.destinationFull;
    }
    if (_tubes[destination].isNotEmpty &&
        _tubes[destination].last != _tubes[source].last) {
      return WaterSortPourStatus.colorMismatch;
    }
    return null;
  }

  WaterSortMove? _moveFor(int source, int destination) {
    if (source < 0 || source >= tubeCount) return null;
    if (destination < 0 || destination >= tubeCount) return null;
    if (source == destination || _tubes[source].isEmpty) return null;
    final targetSpace = capacity - _tubes[destination].length;
    if (targetSpace == 0) return null;

    final color = _tubes[source].last;
    if (_tubes[destination].isNotEmpty && _tubes[destination].last != color) {
      return null;
    }

    var matchingTopCount = 0;
    for (var index = _tubes[source].length - 1; index >= 0; index--) {
      if (_tubes[source][index] != color) break;
      matchingTopCount++;
    }
    return WaterSortMove(
      source: source,
      destination: destination,
      color: color,
      amount: matchingTopCount < targetSpace ? matchingTopCount : targetSpace,
    );
  }

  static void _validate(int capacity, List<List<int>> tubes) {
    if (capacity < 2) {
      throw ArgumentError.value(capacity, 'capacity', 'Must be at least 2');
    }
    if (tubes.length < 2) {
      throw ArgumentError.value(
        tubes,
        'tubes',
        'Must contain at least 2 tubes',
      );
    }
    if (tubes.every((tube) => tube.isEmpty)) {
      throw ArgumentError.value(
        tubes,
        'tubes',
        'Must contain at least one color',
      );
    }
    for (var index = 0; index < tubes.length; index++) {
      final tube = tubes[index];
      if (tube.length > capacity) {
        throw ArgumentError.value(
          tube,
          'tubes[$index]',
          'Cannot exceed tube capacity',
        );
      }
      if (tube.any((color) => color < 0)) {
        throw ArgumentError.value(
          tube,
          'tubes[$index]',
          'Color IDs cannot be negative',
        );
      }
    }
  }

  static List<List<int>> _freezeTubes(List<List<int>> tubes) =>
      UnmodifiableListView([
        for (final tube in tubes) UnmodifiableListView(List<int>.of(tube)),
      ]);
}
