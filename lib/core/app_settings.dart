import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'match_options.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this._preferences) {
    final saved = _preferences.get('winningScore');
    _winningScore = allowedScores.contains(saved) ? saved as int : 7;
    final favourites = _preferences.get('favouriteGameIds');
    _favouriteIds = favourites is List
        ? favourites.whereType<String>().toSet()
        : <String>{};
  }

  static const allowedScores = [5, 7, 11];
  final SharedPreferences _preferences;
  late int _winningScore;
  int get winningScore => _winningScore;
  late Set<String> _favouriteIds;
  Set<String> get favouriteIds => Set.unmodifiable(_favouriteIds);
  bool isFavourite(String id) => _favouriteIds.contains(id);
  Future<void> _pendingWrite = Future.value();

  // Serialize writes so rapid callers cannot overwrite each other's favourites.
  Future<void> _write(Future<void> Function() action) {
    final result = _pendingWrite.then((_) => action());
    _pendingWrite = result.catchError((Object _) {});
    return result;
  }

  Future<void> setWinningScore(int value) => _write(() async {
    if (!allowedScores.contains(value)) return;
    if (!await _preferences.setInt('winningScore', value)) {
      throw StateError('Could not save settings');
    }
    _winningScore = value;
    notifyListeners();
  });

  Future<void> setFavourite(String id, bool favourite) => _write(() async {
    final next = {..._favouriteIds};
    favourite ? next.add(id) : next.remove(id);
    if (!await _preferences.setStringList('favouriteGameIds', next.toList())) {
      throw StateError('Could not save favourite');
    }
    _favouriteIds = next;
    notifyListeners();
  });

  final Map<String, GamePreferences> _gamePreferences = {};

  GamePreferences preferencesFor(String id) =>
      _gamePreferences.putIfAbsent(id, () => _readGamePreferences(id));

  GamePreferences _readGamePreferences(String id) {
    final stored = _preferences.get('gameSetup.$id');
    if (stored is! String) return const GamePreferences();
    try {
      final data = jsonDecode(stored);
      if (data is! Map) return const GamePreferences();
      return GamePreferences(
        mode: PlayMode.values.firstWhere(
          (value) => value.name == data['mode'],
          orElse: () => PlayMode.friend,
        ),
        difficulty: BotDifficulty.values.firstWhere(
          (value) => value.name == data['difficulty'],
          orElse: () => BotDifficulty.normal,
        ),
      );
    } on FormatException {
      return const GamePreferences();
    }
  }

  Future<void> saveGamePreferences(String id, GamePreferences preferences) =>
      _write(() async {
        preferencesFor(id); // Keep the last committed state if storage fails.
        final data = jsonEncode({
          'mode': preferences.mode.name,
          'difficulty': preferences.difficulty.name,
        });
        if (!await _preferences.setString('gameSetup.$id', data)) {
          throw StateError('Could not save game options');
        }
        _gamePreferences[id] = preferences;
        notifyListeners();
      });
}
