import 'package:flutter/material.dart';

import '../../app/game_catalog.dart';
import '../../core/app_settings.dart';
import '../match/match_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.settings, super.key});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
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
                      builder: (_) => _SettingsSheet(settings: settings),
                    ),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 36),
              const Text(
                'One phone.\nTwo rivals.',
                style: TextStyle(
                  fontSize: 48,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'A little friendly competition.\nPick a game and take your side.',
                style: TextStyle(
                  fontSize: 17,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: 24),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(icon: Icons.people_alt_outlined, label: '2 players'),
                  _Badge(icon: Icons.wifi_off_rounded, label: 'Always offline'),
                ],
              ),
              const SizedBox(height: 36),
              const Text(
                'PICK YOUR CHALLENGE',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              for (final game in gameCatalog)
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 180,
                        child:
                            game.preview?.call(context) ??
                            Icon(game.icon, size: 64),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game.title,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              game.subtitle,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => MatchScreen(
                                      game: game,
                                      winningScore: settings.winningScore,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Let’s play'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    size: 18,
                    color: Colors.white54,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'More tiny games. More big rivalries.\nNew challenges are on the way.',
                      style: TextStyle(color: Colors.white54, height: 1.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white12),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF9DF5CF)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
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
