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

enum RecordMetricFormat { integer, duration }

enum RecordSortOrder { higherIsBetter, lowerIsBetter }

class RecordMetricDefinition {
  const RecordMetricDefinition({
    required this.id,
    required this.label,
    required this.format,
    required this.sortOrder,
  });

  final String id;
  final String label;
  final RecordMetricFormat format;
  final RecordSortOrder sortOrder;
}

/// Metrics are compared in order, so later entries are tie-breakers.
class GameRecordDefinition {
  GameRecordDefinition({
    required this.primaryMetric,
    List<RecordMetricDefinition> tieBreakers = const [],
  }) : tieBreakers = List.unmodifiable(tieBreakers);

  final RecordMetricDefinition primaryMetric;
  final List<RecordMetricDefinition> tieBreakers;

  List<RecordMetricDefinition> get metrics => [primaryMetric, ...tieBreakers];
}

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
    this.matchLabel,
    this.botInstructions,
    Set<PlayMode> supportedModes = const {PlayMode.friend},
    Set<PlayerCount> supportedPlayerCounts = const {PlayerCount.two},
    this.difficultyType = DifficultyType.none,
    this.recordDefinition,
  }) : supportedModes = Set.unmodifiable(supportedModes),
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

  bool supportsPlayerCount(PlayerCount count) =>
      supportedPlayerCounts.contains(count);

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
