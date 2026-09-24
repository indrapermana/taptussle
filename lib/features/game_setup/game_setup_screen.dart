import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/match_options.dart';
import '../../core/mini_game.dart';
import '../../core/sound_service.dart';
import '../match/match_screen.dart';

class GameSetupScreen extends StatefulWidget {
  const GameSetupScreen({
    required this.game,
    required this.settings,
    super.key,
  });

  final MiniGame game;
  final AppSettings settings;

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  bool saving = false;

  Future<void> _save(Future<void> Function() action) async {
    setState(() => saving = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _startFriend() {
    final preferences = widget.settings
        .preferencesFor(widget.game.id)
        .copyWith(mode: PlayMode.friend);
    _save(() async {
      await widget.settings.saveGamePreferences(widget.game.id, preferences);
      if (mounted) _openMatch(preferences);
    });
  }

  void _openMatch(GamePreferences preferences) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MatchScreen(
        game: widget.game,
        options: preferences.matchOptions(widget.settings.winningScore),
        resolution: widget.settings.resolution,
        frameRate: widget.settings.frameRate,
        startImmediately: true,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.settings,
    builder: (context, _) {
      final favourite = widget.settings.isFavourite(widget.game.id);
      return Scaffold(
        appBar: AppBar(title: Text(widget.game.title)),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text(
                    'How to play',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.game.instructions,
                    style: const TextStyle(height: 1.6, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  if (widget.game.matchLabel != null)
                    Text(
                      widget.game.matchLabel!(
                        MatchOptions.friend(
                          winningScore: widget.settings.winningScore,
                        ),
                      ),
                      style: const TextStyle(
                        color: Color(0xFF9DF5CF),
                        letterSpacing: 1,
                      ),
                    ),
                  const SizedBox(height: 28),
                  OutlinedButton.icon(
                    key: const ValueKey('favourite-toggle'),
                    onPressed: saving
                        ? null
                        : () {
                            SoundEffects.play(SoundEffect.click);
                            _save(
                              () => widget.settings.setFavourite(
                                widget.game.id,
                                !favourite,
                              ),
                            );
                          },
                    icon: Icon(
                      favourite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                    label: Text(
                      favourite ? 'Remove favourite' : 'Add to favourites',
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Choose participants',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _ModeButton(
                    key: const ValueKey('play-vs-friend'),
                    icon: Icons.people_alt_outlined,
                    title: 'Play vs Friend',
                    subtitle: 'Two players, one phone',
                    onPressed: saving
                        ? null
                        : () {
                            SoundEffects.play(SoundEffect.click);
                            _startFriend();
                          },
                  ),
                  if (widget.game.supportedModes.contains(PlayMode.bot)) ...[
                    const SizedBox(height: 12),
                    _ModeButton(
                      key: const ValueKey('play-vs-bot'),
                      icon: Icons.smart_toy_outlined,
                      title: 'Play vs Bot',
                      subtitle: 'Choose a difficulty next',
                      onPressed: saving
                          ? null
                          : () {
                              SoundEffects.play(SoundEffect.click);
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => BotDifficultyScreen(
                                    game: widget.game,
                                    settings: widget.settings,
                                  ),
                                ),
                              );
                            },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class BotDifficultyScreen extends StatefulWidget {
  const BotDifficultyScreen({
    required this.game,
    required this.settings,
    super.key,
  });

  final MiniGame game;
  final AppSettings settings;

  @override
  State<BotDifficultyScreen> createState() => _BotDifficultyScreenState();
}

class _BotDifficultyScreenState extends State<BotDifficultyScreen> {
  late BotDifficulty difficulty;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    difficulty = widget.settings.preferencesFor(widget.game.id).difficulty;
  }

  String get description => switch (difficulty) {
    BotDifficulty.easy => 'Slower reactions and forgiving returns.',
    BotDifficulty.normal => 'A balanced challenge with steady tracking.',
    BotDifficulty.hard => 'Fast reactions and sharper, but beatable returns.',
  };

  Future<void> _play() async {
    setState(() => saving = true);
    try {
      final preferences = widget.settings
          .preferencesFor(widget.game.id)
          .copyWith(mode: PlayMode.bot, difficulty: difficulty);
      await widget.settings.saveGamePreferences(widget.game.id, preferences);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => MatchScreen(
              game: widget.game,
              options: preferences.matchOptions(widget.settings.winningScore),
              resolution: widget.settings.resolution,
              frameRate: widget.settings.frameRate,
              startImmediately: true,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bot difficulty')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'How tough should the bot be?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 48),
              Text(
                difficulty.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 36,
                  color: Color(0xFF9DF5CF),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 28),
              Slider(
                key: const ValueKey('bot-difficulty-slider'),
                value: difficulty.index.toDouble(),
                min: 0,
                max: 2,
                divisions: 2,
                label: difficulty.label,
                onChanged: saving
                    ? null
                    : (value) => setState(
                        () => difficulty = BotDifficulty.values[value.round()],
                      ),
              ),
              const SizedBox(height: 48),
              FilledButton.icon(
                key: const ValueKey('start-bot-match'),
                onPressed: saving
                    ? null
                    : () {
                        SoundEffects.play(SoundEffect.click);
                        _play();
                      },
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Play ${difficulty.label}'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.all(18),
    ),
    child: Row(
      children: [
        Icon(icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        const Icon(Icons.arrow_forward_rounded),
      ],
    ),
  );
}
