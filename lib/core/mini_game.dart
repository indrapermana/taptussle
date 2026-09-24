import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'match_session.dart';
import 'match_options.dart';

typedef MiniGameBuilder =
    Widget Function(MatchSession session, MatchOptions options);
typedef MiniGamePresentationBuilder =
    Widget Function(
      MatchSession session,
      MatchOptions options,
      ResolutionPreset resolution,
      FrameRatePreset frameRate,
    );

/// Exposes a widget so pure Flutter games can use the same shell as Flame games.
class MiniGame {
  const MiniGame({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.instructions,
    required this.icon,
    required this.build,
    this.buildWithPresentation,
    this.preview,
    this.matchLabel,
    this.botInstructions,
    this.supportedModes = const {PlayMode.friend},
  });

  final String id;
  final String title;
  final String subtitle;
  final String instructions;
  final String? botInstructions;
  final Set<PlayMode> supportedModes;

  String instructionsFor(PlayMode mode) =>
      mode == PlayMode.bot ? botInstructions ?? instructions : instructions;
  final IconData icon;
  final MiniGameBuilder build;
  final MiniGamePresentationBuilder? buildWithPresentation;
  final WidgetBuilder? preview;
  final String Function(MatchOptions options)? matchLabel;
}

/// Stable partition: unknown saved IDs are harmless and catalog order is retained.
List<MiniGame> favouritesFirst(
  List<MiniGame> games,
  Set<String> favouriteIds,
) => [
  ...games.where((game) => favouriteIds.contains(game.id)),
  ...games.where((game) => !favouriteIds.contains(game.id)),
];
