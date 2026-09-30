import 'package:flutter/material.dart';

import '../core/mini_game.dart';
import '../core/match_options.dart';
import 'game_logo_assets.dart';
import '../games/paddle_duel/paddle_duel_view.dart';
import '../games/reaction_duel/reaction_duel_view.dart';
import '../games/air_hockey/air_hockey_view.dart';
import '../games/lane_dash/lane_dash_view.dart';
import '../games/tic_tac_toe/tic_tac_toe_view.dart';
import '../games/memory_match/memory_match_view.dart';
import '../games/rock_paper_scissors/rock_paper_scissors_view.dart';
import '../games/snakes_and_ladders/snakes_and_ladders_view.dart';
import '../games/sudoku/sudoku_view.dart';
import '../games/checkers/checkers_view.dart';

// Composition root: the only shared file that imports individual game modules.
final gameCatalog = List<MiniGame>.unmodifiable([
  MiniGame(
    id: 'sudoku',
    artworkAsset: gameLogoAssets['sudoku'],
    title: 'Sudoku',
    subtitle: 'Think ahead. Fill every square.',
    instructions:
        'Fill the 9×9 board so every row, column, and 3×3 box contains the '
        'numbers 1–9 once. Use Notes to track candidates, erase freely, or use '
        'up to three hints. Incorrect entries count as mistakes. Finish levels '
        'to unlock the next puzzle in that difficulty.',
    icon: Icons.grid_on_rounded,
    supportedModes: const {PlayMode.solo},
    supportedPlayerCounts: const {PlayerCount.one},
    difficultyType: DifficultyType.puzzle,
    difficultyDescription: (difficulty) => switch (difficulty) {
      BotDifficulty.easy =>
        'Straightforward scanning and single-candidate logic.',
      BotDifficulty.normal => 'Adds locked candidates and pair techniques.',
      BotDifficulty.hard => 'Advanced deductions for experienced solvers.',
    },
    recordDefinition: GameRecordDefinition(
      primaryMetric: const RecordMetricDefinition(
        id: 'level',
        label: 'Level',
        format: RecordMetricFormat.integer,
        sortOrder: RecordSortOrder.higherIsBetter,
      ),
      tieBreakers: const [
        RecordMetricDefinition(
          id: 'unassisted',
          label: 'Unassisted',
          format: RecordMetricFormat.integer,
          sortOrder: RecordSortOrder.higherIsBetter,
        ),
        RecordMetricDefinition(
          id: 'mistakes',
          label: 'Mistakes',
          format: RecordMetricFormat.integer,
          sortOrder: RecordSortOrder.lowerIsBetter,
        ),
        RecordMetricDefinition(
          id: 'time',
          label: 'Time',
          format: RecordMetricFormat.duration,
          sortOrder: RecordSortOrder.lowerIsBetter,
        ),
      ],
    ),
    matchLabel: (options) =>
        '${options.difficulty.label.toUpperCase()} • LEVELS 1–60',
    build: (session, options) => SudokuView(session: session, options: options),
  ),
  MiniGame(
    id: 'memory-match',
    artworkAsset: gameLogoAssets['memory-match'],
    title: 'Memory Match',
    subtitle: 'Flip, remember, pair them all.',
    instructions:
        'Choose a difficulty, then flip two cards at a time. Matching cards '
        'stay open. In solo play, find every pair in as few moves and as '
        'little time as possible. With a friend, a match keeps your turn and '
        'a mismatch passes it; the most pairs wins.',
    botInstructions:
        'Flip two cards to find a pair. A match keeps your turn and a mismatch '
        'passes it. The bot remembers only cards that have been revealed; '
        'higher difficulties remember more. The most pairs wins.',
    icon: Icons.style_rounded,
    supportedModes: const {PlayMode.solo, PlayMode.friend, PlayMode.bot},
    supportedPlayerCounts: const {PlayerCount.one, PlayerCount.two},
    difficultyType: DifficultyType.challenge,
    recordDefinition: GameRecordDefinition(
      primaryMetric: const RecordMetricDefinition(
        id: 'moves',
        label: 'Moves',
        format: RecordMetricFormat.integer,
        sortOrder: RecordSortOrder.lowerIsBetter,
      ),
      tieBreakers: const [
        RecordMetricDefinition(
          id: 'time',
          label: 'Time',
          format: RecordMetricFormat.duration,
          sortOrder: RecordSortOrder.lowerIsBetter,
        ),
      ],
    ),
    matchLabel: (options) => options.mode == PlayMode.solo
        ? options.difficulty.label.toUpperCase()
        : '${options.difficulty.label.toUpperCase()} • MOST PAIRS',
    build: (session, options) =>
        MemoryMatchView(session: session, options: options),
  ),
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
  MiniGame(
    id: 'rock-paper-scissors',
    artworkAsset: gameLogoAssets['rock-paper-scissors'],
    title: 'Rock Paper Scissors',
    subtitle: 'Choose. Reveal. Outsmart.',
    instructions:
        'Choose Rock, Paper, or Scissors. Rock beats Scissors, Scissors beats '
        'Paper, and Paper beats Rock. With a friend, lock your choice and pass '
        'the device without revealing it. Both choices appear together. First '
        'to the configured score wins.',
    botInstructions:
        'Choose Rock, Paper, or Scissors before the bot responds. The bot uses '
        'only choices revealed in completed rounds and never reads your current '
        'hidden choice. First to the configured score wins.',
    icon: Icons.sports_mma_rounded,
    supportedModes: const {PlayMode.friend, PlayMode.bot},
    supportedPlayerCounts: const {PlayerCount.two},
    difficultyType: DifficultyType.bot,
    matchLabel: (options) => 'FIRST TO ${options.winningScore}',
    build: (session, options) =>
        RockPaperScissorsView(session: session, options: options),
  ),
  MiniGame(
    id: 'snakes-and-ladders',
    artworkAsset: gameLogoAssets['snakes-and-ladders'],
    title: 'Snakes & Ladders',
    subtitle: 'Climb high. Slide down. Reach 64.',
    instructions:
        'Choose two to four players and take turns rolling the dice. Ladders '
        'move your token upward and snakes send it downward. Players may share '
        'a square. Rolling six does not grant another turn, and you must roll '
        'the exact number needed to reach square 64.',
    botInstructions:
        'Choose two to four participants and assign any non-first seat as a '
        'bot. Every player uses the same fair dice. Bots pause briefly before '
        'rolling. Reach square 64 with an exact roll to win.',
    icon: Icons.casino_rounded,
    supportedModes: const {PlayMode.friend, PlayMode.bot},
    supportedPlayerCounts: const {
      PlayerCount.two,
      PlayerCount.three,
      PlayerCount.four,
    },
    difficultyType: DifficultyType.none,
    matchLabel: (_) => 'FIRST TO SQUARE 64',
    build: (session, options) =>
        SnakesAndLaddersView(session: session, options: options),
  ),
  MiniGame(
    id: 'checkers',
    artworkAsset: gameLogoAssets['checkers'],
    title: 'Checkers',
    subtitle: 'Capture. Crown. Control the board.',
    instructions:
        'Move one red piece diagonally forward on the dark squares. Captures '
        'are mandatory: jump over an opposing piece into the empty square '
        'beyond it, and continue jumping with the same piece whenever another '
        'capture is available. Reach the far edge to crown a king, which can '
        'move and capture in both directions. Win by taking every opposing '
        'piece or leaving your opponent without a legal move.',
    botInstructions:
        'You control the red pieces and move first. Captures are mandatory, '
        'including every available jump in a capture chain. Crown kings by '
        'reaching the far edge and leave the bot without a legal move to win.',
    icon: Icons.circle_outlined,
    supportedModes: const {PlayMode.friend, PlayMode.bot},
    supportedPlayerCounts: const {PlayerCount.two},
    difficultyType: DifficultyType.bot,
    difficultyDescription: (difficulty) => switch (difficulty) {
      BotDifficulty.easy => 'Random legal moves with a relaxed thinking pace.',
      BotDifficulty.normal =>
        'Looks two turns ahead but occasionally makes a weaker move.',
      BotDifficulty.hard =>
        'Looks four turns ahead and values position, promotion, and material.',
    },
    matchLabel: (_) => 'AMERICAN CHECKERS',
    build: (session, options) =>
        CheckersView(session: session, options: options),
  ),
]);
