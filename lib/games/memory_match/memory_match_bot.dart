import 'dart:collection';
import 'dart:math';

import '../../core/match_options.dart';

/// A fair Memory Match bot that only knows identities passed to [observeCard].
///
/// The controller calls [observeCard] after a card is legitimately revealed.
/// Hidden cards and the shuffled deck are deliberately absent from this API.
class MemoryMatchBot {
  MemoryMatchBot({required this.difficulty, Random? random})
    : _random = random ?? Random();

  final BotDifficulty difficulty;
  final Random _random;
  final LinkedHashMap<int, int> _memory = LinkedHashMap<int, int>();

  int get rememberedCardCount => _memory.length;

  int get _memoryLimit => switch (difficulty) {
    BotDifficulty.easy => 4,
    BotDifficulty.normal => 10,
    BotDifficulty.hard => 1 << 30,
  };

  double get _recallChance => switch (difficulty) {
    BotDifficulty.easy => .55,
    BotDifficulty.normal => .85,
    BotDifficulty.hard => 1,
  };

  void observeCard(int index, int pairId) {
    // Refresh a repeated observation so recent cards survive limited memory.
    _memory.remove(index);
    _memory[index] = pairId;
    while (_memory.length > _memoryLimit) {
      _memory.remove(_memory.keys.first);
    }
  }

  void reset() => _memory.clear();

  /// Chooses only from [legalIndexes]. When [revealedPairId] is supplied, the
  /// bot is choosing the second card of its turn.
  int? chooseCard({required List<int> legalIndexes, int? revealedPairId}) {
    if (legalIndexes.isEmpty) return null;
    final legal = legalIndexes.toSet();

    if (_random.nextDouble() < _recallChance) {
      final rememberedChoice = revealedPairId == null
          ? _knownPairChoice(legal)
          : _knownMatchChoice(legal, revealedPairId);
      if (rememberedChoice != null) return rememberedChoice;
    }

    return legalIndexes[_random.nextInt(legalIndexes.length)];
  }

  int? _knownMatchChoice(Set<int> legal, int pairId) {
    for (final entry in _memory.entries) {
      if (legal.contains(entry.key) && entry.value == pairId) return entry.key;
    }
    return null;
  }

  int? _knownPairChoice(Set<int> legal) {
    final firstByPair = <int, int>{};
    for (final entry in _memory.entries) {
      if (!legal.contains(entry.key)) continue;
      final first = firstByPair[entry.value];
      if (first != null) return first;
      firstByPair[entry.value] = entry.key;
    }
    return null;
  }
}
