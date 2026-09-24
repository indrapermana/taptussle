import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/mini_game.dart';
import '../game_setup/game_setup_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.settings, required this.games, super.key});

  final AppSettings settings;
  final List<MiniGame> games;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: CustomScrollView(
              key: const PageStorageKey('game-selection'),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              color: Color(0xFF9DF5CF),
                              size: 30,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'TAPTUSSLE',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Settings',
                              onPressed: () => showModalBottomSheet<void>(
                                context: context,
                                showDragHandle: true,
                                isScrollControlled: true,
                                builder: (_) =>
                                    _SettingsSheet(settings: settings),
                              ),
                              icon: const Icon(Icons.tune_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          'One phone.\nTwo rivals.',
                          style: TextStyle(
                            fontSize: 42,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Pick a challenge and take your side.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'PICK YOUR CHALLENGE',
                          style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 260,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: .92,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final game = favouritesFirst(
                        games,
                        settings.favouriteIds,
                      )[index];
                      return _GameTile(game: game, settings: settings);
                    }, childCount: games.length),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game, required this.settings});

  final MiniGame game;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => Card(
    key: ValueKey('game-card-${game.id}'),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: Semantics(
      button: true,
      label: 'Open ${game.title}',
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => GameSetupScreen(game: game, settings: settings),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            game.preview?.call(context) ??
                Center(child: Icon(game.icon, size: 64)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .86),
                  ],
                  stops: const [.42, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  game.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (settings.isFavourite(game.id))
              const Positioned(
                top: 10,
                right: 10,
                child: Icon(Icons.favorite_rounded, color: Color(0xFFFF968A)),
              ),
          ],
        ),
      ),
    ),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.settings});

  final AppSettings settings;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool saving = false;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Make it your match',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text('Paddle Duel • points to win'),
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: [
              for (final score in AppSettings.allowedScores)
                ButtonSegment(value: score, label: Text('$score')),
            ],
            selected: {widget.settings.winningScore},
            onSelectionChanged: saving
                ? null
                : (selection) async {
                    setState(() => saving = true);
                    try {
                      await widget.settings.setWinningScore(selection.single);
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not save. Please try again.'),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
          ),
          const SizedBox(height: 16),
          const Text(
            'Saved on this device. Applies to your next match.',
            style: TextStyle(color: Colors.white60),
          ),
        ],
      ),
    ),
  );
}
