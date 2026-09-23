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
    await settings.setWinningScore(5);
    final restored = AppSettings(prefs);
    addTearDown(restored.dispose);
    expect(restored.winningScore, 5);
    await settings.setWinningScore(-1);
    expect(settings.winningScore, 5);
  });
}
