import 'dart:collection';

import 'nuts_and_bolts_model.dart';

class NutsAndBoltsSolution {
  const NutsAndBoltsSolution({
    required this.moves,
    required this.exploredStates,
  });

  final List<NutsAndBoltsMove> moves;
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

  final NutsAndBoltsModel model;
  final String key;
  final String? parentKey;
  final NutsAndBoltsMove? move;
}

/// Exact breadth-first solver used to verify shipped Nuts and Bolts levels.
class NutsAndBoltsSolver {
  const NutsAndBoltsSolver({this.maxStates = 500000});

  final int maxStates;

  NutsAndBoltsSolution? solve(NutsAndBoltsModel initial) {
    if (initial.isComplete) {
      return const NutsAndBoltsSolution(moves: [], exploredStates: 1);
    }
    final rootModel = NutsAndBoltsModel(
      bolts: initial.bolts,
      capacity: initial.capacity,
    );
    final rootKey = stateKey(rootModel.bolts);
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
        final moved = current.model.move(move.source, move.destination).model;
        final next = NutsAndBoltsModel(
          bolts: moved.bolts,
          capacity: initial.capacity,
        );
        final key = stateKey(next.bolts);
        if (nodes.containsKey(key)) continue;
        final node = _SearchNode(
          model: next,
          key: key,
          parentKey: current.key,
          move: move,
        );
        nodes[key] = node;
        if (next.isComplete) {
          return NutsAndBoltsSolution(
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

  List<NutsAndBoltsMove> _productiveMoves(NutsAndBoltsModel model) {
    final moves = <NutsAndBoltsMove>[];
    final emptySources = <int>{};
    final equivalentTargets = <String>{};
    for (final move in model.legalMoves) {
      final source = model.bolts[move.source];
      final destination = model.bolts[move.destination];
      if (destination.isEmpty &&
          source.every((color) => color == source.first)) {
        continue;
      }
      if (destination.isEmpty && !emptySources.add(move.source)) continue;
      final targetKey = '${move.source}:${destination.join(',')}';
      if (!equivalentTargets.add(targetKey)) continue;
      moves.add(move);
    }
    return moves;
  }

  List<NutsAndBoltsMove> _pathTo(
    _SearchNode goal,
    Map<String, _SearchNode> nodes,
  ) {
    final reversed = <NutsAndBoltsMove>[];
    var current = goal;
    while (current.parentKey != null) {
      reversed.add(current.move!);
      current = nodes[current.parentKey]!;
    }
    return reversed.reversed.toList(growable: false);
  }

  /// Bolt order is irrelevant, so equivalent arrangements share a state key.
  static String stateKey(List<List<int>> bolts) {
    final encoded = [for (final bolt in bolts) bolt.join(',')]..sort();
    return encoded.join('|');
  }
}
