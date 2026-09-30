import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'water_sort_levels.dart';
import 'water_sort_model.dart';

class WaterSortPersonalBest {
  const WaterSortPersonalBest({
    required this.moves,
    required this.elapsedMilliseconds,
  });

  final int moves;
  final int elapsedMilliseconds;

  bool isBetterThan(WaterSortPersonalBest other) =>
      moves < other.moves ||
      (moves == other.moves && elapsedMilliseconds < other.elapsedMilliseconds);
}

class WaterSortProgressSnapshot {
  const WaterSortProgressSnapshot({
    required this.difficulty,
    required this.level,
    required this.moves,
    required this.elapsedMilliseconds,
  });

  final WaterSortDifficulty difficulty;
  final int level;
  final List<WaterSortMove> moves;
  final int elapsedMilliseconds;

  WaterSortModel restoreModel() {
    final definition = WaterSortLevelCatalog.level(difficulty, level);
    return WaterSortModel.restore(
      initialTubes: definition.tubes,
      capacity: definition.capacity,
      moves: moves,
    );
  }
}

class WaterSortProgressRepository {
  WaterSortProgressRepository(this._preferences);

  static const _version = 1;
  final SharedPreferences _preferences;
  Future<void> _pendingWrite = Future.value();

  String _activeKey(WaterSortDifficulty difficulty) =>
      'waterSort.active.${difficulty.name}.v1';
  String _profileKey(WaterSortDifficulty difficulty) =>
      'waterSort.profile.${difficulty.name}.v1';

  int unlockedLevel(WaterSortDifficulty difficulty) =>
      _readProfile(difficulty).unlockedLevel;

  Set<int> completedLevels(WaterSortDifficulty difficulty) =>
      Set.unmodifiable(_readProfile(difficulty).completedLevels);

  WaterSortPersonalBest? personalBest(
    WaterSortDifficulty difficulty,
    int level,
  ) => _readProfile(difficulty).bests[level];

  WaterSortProgressSnapshot? loadActive(WaterSortDifficulty difficulty) {
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
      if (level > WaterSortLevelCatalog.levelsPerDifficulty) return null;
      final rawMoves = data['moves'];
      if (rawMoves is! List) return null;
      final moves = <WaterSortMove>[];
      for (final rawMove in rawMoves) {
        if (rawMove is! Map) return null;
        moves.add(
          WaterSortMove(
            source: _nonNegativeInteger(rawMove['source']),
            destination: _nonNegativeInteger(rawMove['destination']),
            color: _nonNegativeInteger(rawMove['color']),
            amount: _positiveInteger(rawMove['amount']),
          ),
        );
      }
      final snapshot = WaterSortProgressSnapshot(
        difficulty: difficulty,
        level: level,
        moves: List.unmodifiable(moves),
        elapsedMilliseconds: _nonNegativeInteger(data['elapsedMilliseconds']),
      );
      final restored = snapshot.restoreModel();
      if (restored.isComplete) return null;
      return snapshot;
    } on Object {
      return null;
    }
  }

  Future<void> saveActive({
    required WaterSortLevel level,
    required WaterSortModel model,
    required Duration elapsed,
  }) {
    if (model.isComplete || elapsed.isNegative) {
      throw ArgumentError('Active Water Sort progress must be incomplete');
    }
    final restored = WaterSortModel.restore(
      initialTubes: level.tubes,
      capacity: level.capacity,
      moves: model.moveHistory,
    );
    if (!_sameTubes(restored.tubes, model.tubes)) {
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
            'amount': move.amount,
          },
      ],
      'elapsedMilliseconds': elapsed.inMilliseconds,
    });
    return _enqueue(() async {
      if (!await _preferences.setString(
        _activeKey(level.difficulty),
        encoded,
      )) {
        throw StateError('Could not save Water Sort active puzzle');
      }
    });
  }

  Future<void> clearActive(WaterSortDifficulty difficulty) =>
      _enqueue(() async {
        if (!await _preferences.remove(_activeKey(difficulty))) {
          throw StateError('Could not clear Water Sort active puzzle');
        }
      });

  Future<void> recordCompletion({
    required WaterSortLevel level,
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
        WaterSortLevelCatalog.levelsPerDifficulty,
      );
      if (nextUnlocked > profile.unlockedLevel) {
        profile.unlockedLevel = nextUnlocked;
      }
      final candidate = WaterSortPersonalBest(
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
        throw StateError('Could not save Water Sort completion');
      }
      if (!await _preferences.remove(_activeKey(level.difficulty))) {
        throw StateError('Could not clear completed Water Sort puzzle');
      }
    });
  }

  Future<void> get completed => _pendingWrite;

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _pendingWrite.then((_) => action());
    _pendingWrite = result.catchError((Object _) {});
    return result;
  }

  _WaterSortProfile _readProfile(WaterSortDifficulty difficulty) {
    final fallback = _WaterSortProfile();
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
      if (unlocked > WaterSortLevelCatalog.levelsPerDifficulty) return fallback;
      final rawCompleted = data['completedLevels'];
      final rawBests = data['bests'];
      if (rawCompleted is! List || rawBests is! Map) return fallback;
      final completed = <int>{};
      for (final value in rawCompleted) {
        final level = _positiveInteger(value);
        if (level > WaterSortLevelCatalog.levelsPerDifficulty) return fallback;
        completed.add(level);
      }
      final bests = <int, WaterSortPersonalBest>{};
      for (final entry in rawBests.entries) {
        final level = int.tryParse('${entry.key}');
        final value = entry.value;
        if (level == null ||
            level < 1 ||
            level > WaterSortLevelCatalog.levelsPerDifficulty ||
            value is! Map) {
          return fallback;
        }
        bests[level] = WaterSortPersonalBest(
          moves: _nonNegativeInteger(value['moves']),
          elapsedMilliseconds: _nonNegativeInteger(
            value['elapsedMilliseconds'],
          ),
        );
      }
      return _WaterSortProfile(
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

  static bool _sameTubes(List<List<int>> left, List<List<int>> right) {
    if (left.length != right.length) return false;
    for (var tube = 0; tube < left.length; tube++) {
      if (left[tube].length != right[tube].length) return false;
      for (var slot = 0; slot < left[tube].length; slot++) {
        if (left[tube][slot] != right[tube][slot]) return false;
      }
    }
    return true;
  }
}

class _WaterSortProfile {
  _WaterSortProfile({
    this.unlockedLevel = 1,
    Set<int>? completedLevels,
    Map<int, WaterSortPersonalBest>? bests,
  }) : completedLevels = completedLevels ?? <int>{},
       bests = bests ?? <int, WaterSortPersonalBest>{};

  int unlockedLevel;
  final Set<int> completedLevels;
  final Map<int, WaterSortPersonalBest> bests;
}
