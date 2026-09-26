import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/app_settings.dart';
import '../../core/match_options.dart';
import '../../core/mini_game.dart';
import '../../core/sound_service.dart';
import '../match/match_screen.dart';
import 'participant_setup_screen.dart';

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

  void _startSolo() {
    final preferences = widget.settings
        .preferencesFor(widget.game.id)
        .copyWith(mode: PlayMode.solo);
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
      final supportsSolo =
          widget.game.supportedModes.contains(PlayMode.solo) &&
          widget.game.supportsPlayerCount(PlayerCount.one);
      final usesMultiPlayerSetup = widget.game.supportedPlayerCounts.any(
        (count) => count.value > 2,
      );
      return Scaffold(
        appBar: AppBar(title: Text(widget.game.title)),
        body: TapTussleBackdrop(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    ArcadePanel(
                      accent: TapTussleColors.electricBlue,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeading(
                            icon: Icons.menu_book_rounded,
                            title: 'How to play',
                            color: TapTussleColors.electricBlue,
                          ),
                          const SizedBox(height: 13),
                          Text(
                            widget.game.instructions,
                            style: const TextStyle(
                              height: 1.55,
                              color: TapTussleColors.mutedText,
                            ),
                          ),
                          if (widget.game.matchLabel != null) ...[
                            const SizedBox(height: 16),
                            _RuleBadge(
                              label: widget.game.matchLabel!(
                                MatchOptions.friend(
                                  winningScore: widget.settings.winningScore,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      key: const ValueKey('favourite-toggle'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: favourite
                            ? TapTussleColors.gold
                            : TapTussleColors.text,
                        side: BorderSide(
                          color: favourite
                              ? TapTussleColors.gold
                              : TapTussleColors.panelBorder,
                        ),
                        backgroundColor: TapTussleColors.panel,
                      ),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            favourite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              favourite
                                  ? 'Remove favourite'
                                  : 'Add to favourites',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const _SectionHeading(
                      icon: Icons.sports_esports_rounded,
                      title: 'Choose participants',
                      color: TapTussleColors.gold,
                    ),
                    const SizedBox(height: 12),
                    if (supportsSolo)
                      _ModeButton(
                        key: const ValueKey('play-solo'),
                        icon: Icons.person_rounded,
                        title: 'Play Solo',
                        subtitle: 'Start a one-player game',
                        accent: TapTussleColors.electricBlue,
                        onPressed: saving
                            ? null
                            : () {
                                SoundEffects.play(SoundEffect.click);
                                _startSolo();
                              },
                      ),
                    if (supportsSolo &&
                        widget.game.supportedPlayerCounts.length > 1)
                      const SizedBox(height: 12),
                    if (usesMultiPlayerSetup)
                      _ModeButton(
                        key: const ValueKey('configure-participants'),
                        icon: Icons.groups_rounded,
                        title: 'Set Up Players',
                        subtitle: 'Choose player count and configure each seat',
                        accent: TapTussleColors.gold,
                        onPressed: saving
                            ? null
                            : () {
                                SoundEffects.play(SoundEffect.click);
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => ParticipantSetupScreen(
                                      game: widget.game,
                                      settings: widget.settings,
                                    ),
                                  ),
                                );
                              },
                      )
                    else if (widget.game.supportsPlayerCount(PlayerCount.two) &&
                        widget.game.supportedModes.contains(PlayMode.friend))
                      _ModeButton(
                        key: const ValueKey('play-vs-friend'),
                        icon: Icons.people_alt_rounded,
                        title: 'Play vs Friend',
                        subtitle: 'Two rivals sharing one phone',
                        accent: TapTussleColors.rivalRed,
                        onPressed: saving
                            ? null
                            : () {
                                SoundEffects.play(SoundEffect.click);
                                _startFriend();
                              },
                      ),
                    if (!usesMultiPlayerSetup &&
                        widget.game.supportsPlayerCount(PlayerCount.two) &&
                        widget.game.supportedModes.contains(PlayMode.bot)) ...[
                      const SizedBox(height: 12),
                      _ModeButton(
                        key: const ValueKey('play-vs-bot'),
                        icon: Icons.smart_toy_rounded,
                        title: 'Play vs Bot',
                        subtitle: 'Challenge a local AI rival',
                        accent: TapTussleColors.electricBlue,
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
    BotDifficulty.easy => 'More time to react and more frequent mistakes.',
    BotDifficulty.normal => 'Balanced decisions with occasional mistakes.',
    BotDifficulty.hard => 'Quicker reactions and stronger decisions.',
  };

  Color get difficultyColor => switch (difficulty) {
    BotDifficulty.easy => TapTussleColors.electricBlue,
    BotDifficulty.normal => TapTussleColors.gold,
    BotDifficulty.hard => TapTussleColors.rivalRed,
  };

  IconData get difficultyIcon => switch (difficulty) {
    BotDifficulty.easy => Icons.sentiment_satisfied_alt_rounded,
    BotDifficulty.normal => Icons.local_fire_department_rounded,
    BotDifficulty.hard => Icons.whatshot_rounded,
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
    body: TapTussleBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                const _SectionHeading(
                  icon: Icons.smart_toy_rounded,
                  title: 'How tough should the bot be?',
                  color: TapTussleColors.gold,
                ),
                const SizedBox(height: 18),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: ArcadePanel(
                    accent: difficultyColor,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
                    child: Column(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Container(
                            key: ValueKey(difficulty),
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: difficultyColor.withValues(alpha: .14),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: difficultyColor,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: difficultyColor.withValues(alpha: .25),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                            child: Icon(
                              difficultyIcon,
                              color: difficultyColor,
                              size: 38,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          difficulty.label.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Lilita One',
                            fontSize: 38,
                            height: 1,
                            color: difficultyColor,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: TapTussleColors.mutedText,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: difficultyColor,
                            thumbColor: difficultyColor,
                            overlayColor: difficultyColor.withValues(
                              alpha: .15,
                            ),
                          ),
                          child: Slider(
                            key: const ValueKey('bot-difficulty-slider'),
                            value: difficulty.index.toDouble(),
                            min: 0,
                            max: 2,
                            divisions: 2,
                            label: difficulty.label,
                            onChanged: saving
                                ? null
                                : (value) => setState(
                                    () => difficulty =
                                        BotDifficulty.values[value.round()],
                                  ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'EASY',
                                    style: _difficultyTickStyle,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'NORMAL',
                                    style: _difficultyTickStyle,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'HARD',
                                    style: _difficultyTickStyle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const ValueKey('start-bot-match'),
                  style: FilledButton.styleFrom(
                    backgroundColor: difficultyColor,
                  ),
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
    ),
  );

  static const _difficultyTickStyle = TextStyle(
    color: TapTussleColors.mutedText,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: .8,
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: TapTussleColors.panel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: accent.withValues(alpha: .72), width: 1.3),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: accent.withValues(alpha: .7)),
              ),
              child: Icon(icon, color: accent, size: 27),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Lilita One',
                      color: Colors.white,
                      fontSize: 19,
                      letterSpacing: .2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: TapTussleColors.mutedText,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: accent),
          ],
        ),
      ),
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: color.withValues(alpha: .65)),
        ),
        child: Icon(icon, color: color, size: 21),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Lilita One',
            color: Colors.white,
            fontSize: 24,
            height: 1.05,
          ),
        ),
      ),
    ],
  );
}

class _RuleBadge extends StatelessWidget {
  const _RuleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: TapTussleColors.electricBlue.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: TapTussleColors.electricBlue.withValues(alpha: .55),
      ),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: TapTussleColors.electricBlue,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}
