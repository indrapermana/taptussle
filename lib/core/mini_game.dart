import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'game_record_definition.dart';
import 'match_session.dart';
import 'match_options.dart';

export 'game_record_definition.dart';

typedef MiniGameBuilder =
    Widget Function(MatchSession session, MatchOptions options);
typedef MiniGamePresentationBuilder =
    Widget Function(
      MatchSession session,
      MatchOptions options,
      ResolutionPreset resolution,
      FrameRatePreset frameRate,
    );
typedef RecordVariantBuilder = String Function(GamePreferences preferences);

enum PlayerCount {
  one(1),
  two(2),
  three(3),
  four(4);

  const PlayerCount(this.value);
  final int value;
}

/// Describes what Easy, Normal, and Hard alter for a game.
enum DifficultyType { none, bot, puzzle, challenge }

/// Exposes a widget so pure Flutter games can use the same shell as Flame games.
class MiniGame {
  MiniGame({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.instructions,
    required this.icon,
    required this.build,
    this.buildWithPresentation,
    this.preview,
    this.artworkAsset,
    this.matchLabel,
    this.botInstructions,
    Set<PlayMode> supportedModes = const {PlayMode.friend},
    Set<PlayerCount> supportedPlayerCounts = const {PlayerCount.two},
    this.difficultyType = DifficultyType.none,
    this.recordDefinition,
    this.recordVariant,
  }) : assert(supportedModes.isNotEmpty),
       assert(supportedPlayerCounts.isNotEmpty),
       supportedModes = Set.unmodifiable(supportedModes),
       supportedPlayerCounts = Set.unmodifiable(supportedPlayerCounts);

  final String id;
  final String title;
  final String subtitle;
  final String instructions;
  final String? botInstructions;
  final Set<PlayMode> supportedModes;
  final Set<PlayerCount> supportedPlayerCounts;
  final DifficultyType difficultyType;
  final GameRecordDefinition? recordDefinition;
  final RecordVariantBuilder? recordVariant;

  String recordVariantFor(GamePreferences preferences) =>
      recordVariant?.call(preferences) ??
      (difficultyType == DifficultyType.none
          ? 'default'
          : preferences.difficulty.name);

  bool supportsPlayerCount(PlayerCount count) =>
      supportedPlayerCounts.contains(count);

  String instructionsFor(PlayMode mode) =>
      mode == PlayMode.bot ? botInstructions ?? instructions : instructions;
  final IconData icon;
  final MiniGameBuilder build;
  final MiniGamePresentationBuilder? buildWithPresentation;
  final WidgetBuilder? preview;
  final String? artworkAsset;
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
