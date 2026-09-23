import 'package:flutter/material.dart';

import '../core/mini_game.dart';
import '../games/paddle_duel/paddle_duel_view.dart';
import '../games/paddle_duel/paddle_duel_preview.dart';

// Composition root: the only shared file that imports individual game modules.
final gameCatalog = List<MiniGame>.unmodifiable([
  MiniGame(
    id: 'paddle-duel',
    preview: (_) => const CustomPaint(painter: PaddleDuelPreview()),
    matchLabel: (score) => 'FIRST TO $score',
    title: 'Paddle Duel',
    subtitle: 'Quick hands. Long rallies. One winner.',
    instructions:
        'Sit at opposite ends of the phone. Player 1 controls the '
        'mint paddle at the bottom; Player 2 controls the coral paddle at the '
        'top. Drag anywhere in your half to move your paddle. Get the ball '
        'past your opponent to score.',
    icon: Icons.sports_tennis_rounded,
    build: (session, winningScore) =>
        PaddleDuelView(session: session, winningScore: winningScore),
  ),
]);
