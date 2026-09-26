import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'match_options.dart';

enum ResolutionPreset {
  economy('Economy', .5),
  balanced('Balanced', .75),
  native('Native', 1);

  const ResolutionPreset(this.label, this.renderScale);
  final String label;
  final double renderScale;
}

enum FrameRatePreset {
  fps30(30),
  fps60(60);

  const FrameRatePreset(this.framesPerSecond);
  final int framesPerSecond;
}

enum CatalogPlayerFilter {
  onePlayer('1 Player'),
  twoPlayers('2 Players'),
  upToFourPlayers('Up to 4 Players');

  const CatalogPlayerFilter(this.label);
  final String label;
}

class AppSettings extends ChangeNotifier {
  AppSettings(this._preferences) {
    final saved = _preferences.get('winningScore');
    _winningScore = allowedScores.contains(saved) ? saved as int : 7;
    final favourites = _preferences.get('favouriteGameIds');
    _favouriteIds = favourites is List
        ? favourites.whereType<String>().toSet()
        : <String>{};
    final savedVolume = _preferences.get('effectsVolume');
    _effectsVolume = savedVolume is num && savedVolume >= 0 && savedVolume <= 1
        ? savedVolume.toDouble()
        : .7;
    _vibrationEnabled = _preferences.getBool('vibrationEnabled') ?? true;
    _resolution = ResolutionPreset.values.firstWhere(
      (value) => value.name == _preferences.getString('resolutionPreset'),
      orElse: () => ResolutionPreset.native,
    );
    _frameRate = FrameRatePreset.values.firstWhere(
      (value) => value.name == _preferences.getString('frameRatePreset'),
      orElse: () => FrameRatePreset.fps60,
    );
    _catalogPlayerFilter = CatalogPlayerFilter.values.firstWhere(
      (value) => value.name == _preferences.getString('catalogPlayerFilter'),
      orElse: () => CatalogPlayerFilter.twoPlayers,
    );
  }

  static const allowedScores = [5, 7, 11];
  final SharedPreferences _preferences;
  late int _winningScore;
  int get winningScore => _winningScore;
  late Set<String> _favouriteIds;
  Set<String> get favouriteIds => Set.unmodifiable(_favouriteIds);
  bool isFavourite(String id) => _favouriteIds.contains(id);
  Future<void> _pendingWrite = Future.value();
  late double _effectsVolume;
  double get effectsVolume => _effectsVolume;
  late bool _vibrationEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  late ResolutionPreset _resolution;
  ResolutionPreset get resolution => _resolution;
  late FrameRatePreset _frameRate;
  FrameRatePreset get frameRate => _frameRate;
  late CatalogPlayerFilter _catalogPlayerFilter;
  CatalogPlayerFilter get catalogPlayerFilter => _catalogPlayerFilter;

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

  Future<void> setEffectsVolume(double value) => _write(() async {
    final next = value.clamp(0.0, 1.0).toDouble();
    if (!await _preferences.setDouble('effectsVolume', next)) {
      throw StateError('Could not save effects volume');
    }
    _effectsVolume = next;
    notifyListeners();
  });

  Future<void> setVibrationEnabled(bool value) => _write(() async {
    if (!await _preferences.setBool('vibrationEnabled', value)) {
      throw StateError('Could not save vibration setting');
    }
    _vibrationEnabled = value;
    notifyListeners();
  });

  Future<void> setResolution(ResolutionPreset value) => _write(() async {
    if (!await _preferences.setString('resolutionPreset', value.name)) {
      throw StateError('Could not save resolution setting');
    }
    _resolution = value;
    notifyListeners();
  });

  Future<void> setFrameRate(FrameRatePreset value) => _write(() async {
    if (!await _preferences.setString('frameRatePreset', value.name)) {
      throw StateError('Could not save FPS setting');
    }
    _frameRate = value;
    notifyListeners();
  });

  Future<void> setCatalogPlayerFilter(CatalogPlayerFilter value) =>
      _write(() async {
        if (!await _preferences.setString('catalogPlayerFilter', value.name)) {
          throw StateError('Could not save player filter');
        }
        _catalogPlayerFilter = value;
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
