import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/core/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('default, persistence, and invalid stored values', () async {
    SharedPreferences.setMockInitialValues({'winningScore': 99});
    final prefs = await SharedPreferences.getInstance();
    final settings = AppSettings(prefs);
    addTearDown(settings.dispose);
    expect(settings.winningScore, 7);
    expect(settings.effectsVolume, .7);
    expect(settings.vibrationEnabled, isTrue);
    await settings.setWinningScore(5);
    await settings.setEffectsVolume(.35);
    final restored = AppSettings(prefs);
    addTearDown(restored.dispose);
    expect(restored.winningScore, 5);
    expect(restored.effectsVolume, .35);
    await settings.setWinningScore(-1);
    expect(settings.winningScore, 5);
    await settings.setEffectsVolume(2);
    expect(settings.effectsVolume, 1);
    await settings.setVibrationEnabled(false);
    expect(settings.vibrationEnabled, isFalse);
  });
}
