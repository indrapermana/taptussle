import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'nuts_and_bolts_levels.dart';
import 'nuts_and_bolts_model.dart';

class NutsAndBoltsPersonalBest {
  const NutsAndBoltsPersonalBest({
    required this.moves,
    required this.elapsedMilliseconds,
  });

  final int moves;
  final int elapsedMilliseconds;

  bool isBetterThan(NutsAndBoltsPersonalBest other) =>
      moves < other.moves ||
      (moves == other.moves && elapsedMilliseconds < other.elapsedMilliseconds);
}

class NutsAndBoltsProgressSnapshot {
  const NutsAndBoltsProgressSnapshot({
    required this.difficulty,
    required this.level,
    required this.moves,
    required this.elapsedMilliseconds,
  });

  final NutsAndBoltsDifficulty difficulty;
  final int level;
  final List<NutsAndBoltsMove> moves;
  final int elapsedMilliseconds;

  NutsAndBoltsModel restoreModel() {
    final definition = NutsAndBoltsLevelCatalog.level(difficulty, level);
    return NutsAndBoltsModel.restore(
      initialBolts: definition.bolts,
      capacity: definition.capacity,
      moves: moves,
    );
  }
}

class NutsAndBoltsProgressRepository {
  NutsAndBoltsProgressRepository(this._preferences);

  static const _version = 1;
  final SharedPreferences _preferences;
  Future<void> _pendingWrite = Future.value();

  String _activeKey(NutsAndBoltsDifficulty difficulty) =>
      'nutsAndBolts.active.${difficulty.name}.v1';
  String _profileKey(NutsAndBoltsDifficulty difficulty) =>
      'nutsAndBolts.profile.${difficulty.name}.v1';

  int unlockedLevel(NutsAndBoltsDifficulty difficulty) =>
      _readProfile(difficulty).unlockedLevel;

  Set<int> completedLevels(NutsAndBoltsDifficulty difficulty) =>
      Set.unmodifiable(_readProfile(difficulty).completedLevels);

  NutsAndBoltsPersonalBest? personalBest(
    NutsAndBoltsDifficulty difficulty,
    int level,
  ) => _readProfile(difficulty).bests[level];

  NutsAndBoltsProgressSnapshot? loadActive(NutsAndBoltsDifficulty difficulty) {
    final encoded = _preferences.getString(_activeKey(difficulty));
    if (encoded == null) return null;
    try {
      final data = jsonDecode(encoded);
      if (data is! Map<String, dynamic> ||
          data['version'] != _version ||
          data['difficulty'] != difficulty.name) {
        return null;
      }
      final level = _positiveInteger(data['level']);
      if (level > NutsAndBoltsLevelCatalog.levelsPerDifficulty) return null;
      final rawMoves = data['moves'];
      if (rawMoves is! List) return null;
      final moves = <NutsAndBoltsMove>[];
      for (final rawMove in rawMoves) {
        if (rawMove is! Map) return null;
        moves.add(
          NutsAndBoltsMove(
            source: _nonNegativeInteger(rawMove['source']),
            destination: _nonNegativeInteger(rawMove['destination']),
            color: _nonNegativeInteger(rawMove['color']),
          ),
        );
      }
      final snapshot = NutsAndBoltsProgressSnapshot(
        difficulty: difficulty,
        level: level,
        moves: List.unmodifiable(moves),
        elapsedMilliseconds: _nonNegativeInteger(data['elapsedMilliseconds']),
      );
      if (snapshot.restoreModel().isComplete) return null;
      return snapshot;
    } on Object {
      return null;
    }
  }

  Future<void> saveActive({
    required NutsAndBoltsLevel level,
    required NutsAndBoltsModel model,
    required Duration elapsed,
  }) {
    if (model.isComplete || elapsed.isNegative) {
      throw ArgumentError('Active Nuts and Bolts progress must be incomplete');
    }
    final restored = NutsAndBoltsModel.restore(
      initialBolts: level.bolts,
      capacity: level.capacity,
      moves: model.moveHistory,
    );
    if (!_sameBolts(restored.bolts, model.bolts)) {
      throw ArgumentError('Model does not belong to the supplied level');
    }
    final encoded = jsonEncode({
      'version': _version,
      'difficulty': level.difficulty.name,
      'level': level.number,
      'moves': [
        for (final move in model.moveHistory)
          {
            'source': move.source,
            'destination': move.destination,
            'color': move.color,
          },
      ],
      'elapsedMilliseconds': elapsed.inMilliseconds,
    });
    return _enqueue(() async {
      if (!await _preferences.setString(
        _activeKey(level.difficulty),
        encoded,
      )) {
        throw StateError('Could not save Nuts and Bolts active puzzle');
      }
    });
  }

  Future<void> clearActive(NutsAndBoltsDifficulty difficulty) =>
      _enqueue(() async {
        if (!await _preferences.remove(_activeKey(difficulty))) {
          throw StateError('Could not clear Nuts and Bolts active puzzle');
        }
      });

  Future<void> recordCompletion({
    required NutsAndBoltsLevel level,
    required int moves,
    required Duration elapsed,
  }) {
    if (moves < 0 || elapsed.isNegative) {
      throw ArgumentError('Completion metrics cannot be negative');
    }
    return _enqueue(() async {
      final profile = _readProfile(level.difficulty);
      profile.completedLevels.add(level.number);
      final nextUnlocked = (level.number + 1).clamp(
        1,
        NutsAndBoltsLevelCatalog.levelsPerDifficulty,
      );
      if (nextUnlocked > profile.unlockedLevel) {
        profile.unlockedLevel = nextUnlocked;
      }
      final candidate = NutsAndBoltsPersonalBest(
        moves: moves,
        elapsedMilliseconds: elapsed.inMilliseconds,
      );
      final previous = profile.bests[level.number];
      if (previous == null || candidate.isBetterThan(previous)) {
        profile.bests[level.number] = candidate;
      }
      final encoded = jsonEncode({
        'version': _version,
        'difficulty': level.difficulty.name,
        'unlockedLevel': profile.unlockedLevel,
        'completedLevels': profile.completedLevels.toList()..sort(),
        'bests': {
          for (final entry in profile.bests.entries)
            '${entry.key}': {
              'moves': entry.value.moves,
              'elapsedMilliseconds': entry.value.elapsedMilliseconds,
            },
        },
      });
      if (!await _preferences.setString(
        _profileKey(level.difficulty),
        encoded,
      )) {
        throw StateError('Could not save Nuts and Bolts completion');
      }
      if (!await _preferences.remove(_activeKey(level.difficulty))) {
        throw StateError('Could not clear completed Nuts and Bolts puzzle');
      }
    });
  }

  Future<void> get completed => _pendingWrite;

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _pendingWrite.then((_) => action());
    _pendingWrite = result.catchError((Object _) {});
    return result;
  }

  _NutsAndBoltsProfile _readProfile(NutsAndBoltsDifficulty difficulty) {
    final fallback = _NutsAndBoltsProfile();
    final encoded = _preferences.getString(_profileKey(difficulty));
    if (encoded == null) return fallback;
    try {
      final data = jsonDecode(encoded);
      if (data is! Map<String, dynamic> ||
          data['version'] != _version ||
          data['difficulty'] != difficulty.name) {
        return fallback;
      }
      final unlocked = _positiveInteger(data['unlockedLevel']);
      if (unlocked > NutsAndBoltsLevelCatalog.levelsPerDifficulty) {
        return fallback;
      }
      final rawCompleted = data['completedLevels'];
      final rawBests = data['bests'];
      if (rawCompleted is! List || rawBests is! Map) return fallback;
      final completed = <int>{};
      for (final value in rawCompleted) {
        final level = _positiveInteger(value);
        if (level > NutsAndBoltsLevelCatalog.levelsPerDifficulty) {
          return fallback;
        }
        completed.add(level);
      }
      final bests = <int, NutsAndBoltsPersonalBest>{};
      for (final entry in rawBests.entries) {
        final level = int.tryParse('${entry.key}');
        final value = entry.value;
        if (level == null ||
            level < 1 ||
            level > NutsAndBoltsLevelCatalog.levelsPerDifficulty ||
            value is! Map) {
          return fallback;
        }
        bests[level] = NutsAndBoltsPersonalBest(
          moves: _nonNegativeInteger(value['moves']),
          elapsedMilliseconds: _nonNegativeInteger(
            value['elapsedMilliseconds'],
          ),
        );
      }
      return _NutsAndBoltsProfile(
        unlockedLevel: unlocked,
        completedLevels: completed,
        bests: bests,
      );
    } on Object {
      return fallback;
    }
  }

  static int _positiveInteger(Object? value) {
    if (value is! int || value < 1) {
      throw const FormatException('Expected a positive integer');
    }
    return value;
  }

  static int _nonNegativeInteger(Object? value) {
    if (value is! int || value < 0) {
      throw const FormatException('Expected a non-negative integer');
    }
    return value;
  }

  static bool _sameBolts(List<List<int>> left, List<List<int>> right) {
    if (left.length != right.length) return false;
    for (var bolt = 0; bolt < left.length; bolt++) {
      if (left[bolt].length != right[bolt].length) return false;
      for (var slot = 0; slot < left[bolt].length; slot++) {
        if (left[bolt][slot] != right[bolt][slot]) return false;
      }
    }
    return true;
  }
}

class _NutsAndBoltsProfile {
  _NutsAndBoltsProfile({
    this.unlockedLevel = 1,
    Set<int>? completedLevels,
    Map<int, NutsAndBoltsPersonalBest>? bests,
  }) : completedLevels = completedLevels ?? <int>{},
       bests = bests ?? <int, NutsAndBoltsPersonalBest>{};

  int unlockedLevel;
  final Set<int> completedLevels;
  final Map<int, NutsAndBoltsPersonalBest> bests;
}
