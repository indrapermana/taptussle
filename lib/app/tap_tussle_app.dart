import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/mini_game.dart';
import 'game_catalog.dart';
import '../features/home/home_screen.dart';

class TapTussleApp extends StatelessWidget {
  const TapTussleApp({required this.settings, this.games, super.key});
  final AppSettings settings;
  final List<MiniGame>? games;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TapTussle',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF101A27),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF9DF5CF),
        brightness: Brightness.dark,
        primary: const Color(0xFF9DF5CF),
        secondary: const Color(0xFFFF968A),
        surface: const Color(0xFF1B293A),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ),
    home: HomeScreen(settings: settings, games: games ?? gameCatalog),
  );
}
