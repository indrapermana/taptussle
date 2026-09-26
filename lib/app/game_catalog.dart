import 'package:flutter/material.dart';

import '../core/mini_game.dart';
import '../core/match_options.dart';
import 'game_logo_assets.dart';
import '../games/paddle_duel/paddle_duel_view.dart';
import '../games/reaction_duel/reaction_duel_view.dart';
import '../games/air_hockey/air_hockey_view.dart';
import '../games/lane_dash/lane_dash_view.dart';
import '../games/tic_tac_toe/tic_tac_toe_view.dart';

// Composition root: the only shared file that imports individual game modules.
final gameCatalog = List<MiniGame>.unmodifiable([
  MiniGame(
    id: 'tic-tac-toe',
    artworkAsset: gameLogoAssets['tic-tac-toe'],
    title: 'Tic-Tac-Toe',
    subtitle: 'Three marks. One winning line.',
    instructions:
        'Take turns placing X and O. Complete a horizontal, vertical, or '
        'diagonal line of three marks to win. A full board without a line is '
        'a draw. The starting player alternates after each match.',
    botInstructions:
        'You play X and the bot plays O. Complete a line of three before the '
        'bot. The starting player alternates after each match.',
    icon: Icons.grid_3x3_rounded,
    supportedModes: const {PlayMode.friend, PlayMode.bot},
    supportedPlayerCounts: const {PlayerCount.two},
    difficultyType: DifficultyType.bot,
    matchLabel: (_) => 'THREE IN A ROW',
    build: (session, options) =>
        TicTacToeView(session: session, options: options),
  ),
  MiniGame(
    id: 'lane-dash',
    artworkAsset: gameLogoAssets['lane-dash'],
    title: 'Lane Dash',
    subtitle: 'Dodge, switch, finish.',
    instructions:
        'Race along your own three-lane track. Swipe left or right across your '
        'half to switch lanes and avoid orange cones. Hitting a cone slows you '
        'down. The top runner faces the opposite way. Reach 1,200 m first to win.',
    botInstructions:
        'Swipe left or right across the bottom track to move the mint runner. '
        'Hitting a cone slows you down. Each runner gets a different course. '
        'Higher difficulties add more obstacles while the bot reacts faster '
        'and makes fewer mistakes.',
    icon: Icons.directions_run_rounded,
    supportedModes: const {PlayMode.friend, PlayMode.bot},
    supportedPlayerCounts: const {PlayerCount.two},
    difficultyType: DifficultyType.bot,
    matchLabel: (_) => 'DISTANCE • M',
    build: (session, options) =>
        LaneDashView(session: session, options: options),
  ),
  MiniGame(
    id: 'air-hockey',
    artworkAsset: gameLogoAssets['air-hockey'],
    title: 'Air Hockey',
    subtitle: 'Fast puck. Faster hands.',
    instructions:
        'Sit at opposite ends. Drag your mallet only in your half and score through the opposing goal.',
    icon: Icons.sports_hockey_rounded,
    supportedModes: const {PlayMode.friend, PlayMode.bot},
    supportedPlayerCounts: const {PlayerCount.two},
    difficultyType: DifficultyType.bot,
    botInstructions:
        'You control the mint mallet at the bottom. Defend your goal and drive the puck past the bot.',
    matchLabel: (o) => 'FIRST TO ${o.winningScore}',
    build: (s, o) => AirHockeyView(session: s, options: o),
  ),
  MiniGame(
    id: 'reaction-duel',
    artworkAsset: gameLogoAssets['reaction-duel'],
    matchLabel: (options) => 'FIRST TO ${options.winningScore}',
    supportedModes: const {PlayMode.friend, PlayMode.bot},
    supportedPlayerCounts: const {PlayerCount.two},
    difficultyType: DifficultyType.bot,
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
    artworkAsset: gameLogoAssets['paddle-duel'],
    matchLabel: (options) => 'FIRST TO ${options.winningScore}',
    supportedModes: const {PlayMode.friend, PlayMode.bot},
    supportedPlayerCounts: const {PlayerCount.two},
    difficultyType: DifficultyType.bot,
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
