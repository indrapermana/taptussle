import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';

class GameArtwork extends StatelessWidget {
  const GameArtwork({
    required this.gameId,
    required this.icon,
    required this.accent,
    this.assetPath,
    super.key,
  });

  final String gameId;
  final String? assetPath;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(0, -.15),
        radius: .82,
        colors: [accent.withValues(alpha: .34), TapTussleColors.navy],
      ),
    ),
    child: assetPath == null
        ? _ArtworkFallback(gameId: gameId, icon: icon, accent: accent)
        : Align(
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              widthFactor: 1,
              heightFactor: .82,
              child: Image.asset(
                assetPath!,
                key: ValueKey('game-artwork-$gameId'),
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => _ArtworkFallback(
                  gameId: gameId,
                  icon: icon,
                  accent: accent,
                ),
              ),
            ),
          ),
  );
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({
    required this.gameId,
    required this.icon,
    required this.accent,
  });

  final String gameId;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      key: ValueKey('game-artwork-fallback-$gameId'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TapTussleColors.midnight.withValues(alpha: .62),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: .8)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: .25), blurRadius: 20),
        ],
      ),
      child: Icon(icon, size: 50, color: Colors.white),
    ),
  );
}
