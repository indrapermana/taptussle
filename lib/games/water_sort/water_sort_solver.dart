import 'dart:collection';

import 'water_sort_model.dart';

class WaterSortSolution {
  const WaterSortSolution({required this.moves, required this.exploredStates});

  final List<WaterSortMove> moves;
  final int exploredStates;
  int get moveCount => moves.length;
}

class _SearchNode {
  const _SearchNode({
    required this.model,
    required this.key,
    required this.parentKey,
    required this.move,
  });

  final WaterSortModel model;
  final String key;
  final String? parentKey;
  final WaterSortMove? move;
}

/// Exact breadth-first solver used to verify shipped Water Sort levels.
class WaterSortSolver {
  const WaterSortSolver({this.maxStates = 500000});

  final int maxStates;

  WaterSortSolution? solve(WaterSortModel initial) {
    if (initial.isComplete) {
      return const WaterSortSolution(moves: [], exploredStates: 1);
    }
    final rootModel = WaterSortModel(
      tubes: initial.tubes,
      capacity: initial.capacity,
    );
    final rootKey = stateKey(rootModel.tubes);
    final root = _SearchNode(
      model: rootModel,
      key: rootKey,
      parentKey: null,
      move: null,
    );
    final queue = Queue<_SearchNode>()..add(root);
    final nodes = <String, _SearchNode>{rootKey: root};

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      for (final move in _productiveMoves(current.model)) {
        final poured = current.model.pour(move.source, move.destination).model;
        final next = WaterSortModel(
          tubes: poured.tubes,
          capacity: initial.capacity,
        );
        final key = stateKey(next.tubes);
        if (nodes.containsKey(key)) continue;
        final node = _SearchNode(
          model: next,
          key: key,
          parentKey: current.key,
          move: move,
        );
        nodes[key] = node;
        if (next.isComplete) {
          return WaterSortSolution(
            moves: List.unmodifiable(_pathTo(node, nodes)),
            exploredStates: nodes.length,
          );
        }
        if (nodes.length >= maxStates) return null;
        queue.add(node);
      }
    }
    return null;
  }

  List<WaterSortMove> _productiveMoves(WaterSortModel model) {
    final moves = <WaterSortMove>[];
    final sourcesUsingEmptyTarget = <int>{};
    for (final move in model.legalMoves) {
      final source = model.tubes[move.source];
      final destination = model.tubes[move.destination];
      if (destination.isEmpty &&
          source.every((color) => color == source.first)) {
        continue;
      }
      if (destination.isEmpty && !sourcesUsingEmptyTarget.add(move.source)) {
        continue;
      }
      moves.add(move);
    }
    return moves;
  }

  List<WaterSortMove> _pathTo(
    _SearchNode goal,
    Map<String, _SearchNode> nodes,
  ) {
    final reversed = <WaterSortMove>[];
    var current = goal;
    while (current.parentKey != null) {
      reversed.add(current.move!);
      current = nodes[current.parentKey]!;
    }
    return reversed.reversed.toList(growable: false);
  }

  /// Tube order is irrelevant to the rules, so equivalent arrangements share
  /// one visited-state key while retained nodes keep replayable real indexes.
  static String stateKey(List<List<int>> tubes) {
    final encoded = [for (final tube in tubes) tube.join(',')]..sort();
    return encoded.join('|');
  }
}
