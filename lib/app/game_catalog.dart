import 'package:flutter/material.dart';

import '../core/mini_game.dart';
import '../core/match_options.dart';
import '../games/paddle_duel/paddle_duel_view.dart';
import '../games/paddle_duel/paddle_duel_preview.dart';
import '../games/reaction_duel/reaction_duel_view.dart';
import '../games/air_hockey/air_hockey_view.dart';

// Composition root: the only shared file that imports individual game modules.
final gameCatalog = List<MiniGame>.unmodifiable([
  MiniGame(
    id: 'air-hockey',
    title: 'Air Hockey',
    subtitle: 'Fast puck. Faster hands.',
    instructions:
        'Sit at opposite ends. Drag your mallet only in your half and score through the opposing goal.',
    icon: Icons.sports_hockey_rounded,
    supportedModes: const {PlayMode.friend, PlayMode.bot},
    botInstructions:
        'You control the mint mallet at the bottom. Defend your goal and drive the puck past the bot.',
    matchLabel: (o) => 'FIRST TO ${o.winningScore}',
    build: (s, o) => AirHockeyView(session: s, options: o),
  ),
  MiniGame(
    id: 'reaction-duel',
    matchLabel: (options) => 'FIRST TO ${options.winningScore}',
    supportedModes: const {PlayMode.friend, PlayMode.bot},
    botInstructions:
        'Wait for TAP. You control the mint zone at the bottom; the bot uses the coral zone at the top. Tapping before the signal awards the bot a point.',
    title: 'Reaction Duel',
    subtitle: 'Wait. Watch. Win the tap.',
    instructions:
        'Sit at opposite ends of the phone. Wait for the centre signal to say TAP, then press your own half. A tap before the signal gives your opponent the point. Near-simultaneous taps replay the round.',
    icon: Icons.bolt_rounded,
    build: (session, options) =>
        ReactionDuelView(session: session, options: options),
  ),
  MiniGame(
    id: 'paddle-duel',
    preview: (_) => const CustomPaint(painter: PaddleDuelPreview()),
    matchLabel: (options) => 'FIRST TO ${options.winningScore}',
    supportedModes: const {PlayMode.friend, PlayMode.bot},
    botInstructions:
        'You control the mint paddle at the bottom. Drag in the '
        'bottom half to move; the bot controls the coral paddle at the top. '
        'Get the ball past the bot to score. Hit near a paddle edge to angle '
        'your return.',
    title: 'Paddle Duel',
    subtitle: 'Quick hands. Long rallies. One winner.',
    instructions:
        'Sit at opposite ends of the phone. Player 1 controls the '
        'mint paddle at the bottom; Player 2 controls the coral paddle at the '
        'top. Drag anywhere in your half to move your paddle. Get the ball '
        'past your opponent to score.',
    icon: Icons.sports_tennis_rounded,
    build: (session, options) =>
        PaddleDuelView(session: session, options: options),
    buildWithPresentation: (session, options, resolution, frameRate) =>
        PaddleDuelView(
          session: session,
          options: options,
          resolution: resolution,
          frameRate: frameRate,
        ),
  ),
]);
