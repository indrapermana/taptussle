import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/tap_tussle_app.dart';
import 'core/app_settings.dart';
import 'core/haptic_service.dart';
import 'core/sound_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final preferences = await SharedPreferences.getInstance();
  final settings = AppSettings(preferences);
  final sounds = SoundService();
  final haptics = HapticService(enabled: settings.vibrationEnabled);
  SoundEffects.configure(sounds);
  HapticEffects.configure(haptics);
  sounds.setVolume(settings.effectsVolume);
  settings.addListener(() {
    sounds.setVolume(settings.effectsVolume);
    haptics.setEnabled(settings.vibrationEnabled);
  });
  runApp(TapTussleApp(settings: settings));
}
