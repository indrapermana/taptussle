import 'package:flutter/material.dart';

import 'match_session.dart';

typedef MiniGameBuilder =
    Widget Function(MatchSession session, int winningScore);

/// Exposes a widget so pure Flutter games can use the same shell as Flame games.
class MiniGame {
  const MiniGame({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.instructions,
    required this.icon,
    required this.build,
    this.preview,
    this.matchLabel,
  });

  final String id;
  final String title;
  final String subtitle;
  final String instructions;
  final IconData icon;
  final MiniGameBuilder build;
  final WidgetBuilder? preview;
  final String Function(int winningScore)? matchLabel;
}
