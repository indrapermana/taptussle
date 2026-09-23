import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this._preferences) {
    final saved = _preferences.getInt('winningScore');
    winningScore = allowedScores.contains(saved) ? saved! : 7;
  }

  static const allowedScores = [5, 7, 11];
  final SharedPreferences _preferences;
  late int winningScore;

  Future<void> setWinningScore(int value) async {
    if (!allowedScores.contains(value)) return;
    if (!await _preferences.setInt('winningScore', value)) {
      throw StateError('Could not save settings');
    }
    winningScore = value;
    notifyListeners();
  }
}
