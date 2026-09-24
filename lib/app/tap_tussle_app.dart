import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/mini_game.dart';
import 'game_catalog.dart';
import '../features/home/home_screen.dart';
import 'tap_tussle_theme.dart';

class TapTussleApp extends StatelessWidget {
  const TapTussleApp({required this.settings, this.games, super.key});
  final AppSettings settings;
  final List<MiniGame>? games;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TapTussle',
    debugShowCheckedModeBanner: false,
    theme: buildTapTussleTheme(),
    home: HomeScreen(settings: settings, games: games ?? gameCatalog),
  );
}
