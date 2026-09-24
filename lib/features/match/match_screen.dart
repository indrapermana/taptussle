import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/match_session.dart';
import '../../core/match_options.dart';
import '../../core/app_settings.dart';
import '../../core/mini_game.dart';
import '../../core/sound_service.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({
    required this.game,
    required this.options,
    this.resolution = ResolutionPreset.native,
    this.frameRate = FrameRatePreset.fps60,
    this.startImmediately = false,
    super.key,
  });
  final MiniGame game;
  final MatchOptions options;
  final ResolutionPreset resolution;
  final FrameRatePreset frameRate;
  final bool startImmediately;
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with WidgetsBindingObserver {
  late final MatchSession session;
  late final Widget gameView;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session = MatchSession(options: widget.options);
    gameView =
        widget.game.buildWithPresentation?.call(
          session,
          widget.options,
          widget.resolution,
          widget.frameRate,
        ) ??
        widget.game.build(session, widget.options);
    if (widget.startImmediately) session.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) session.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => PopScope(
      canPop: session.phase != MatchPhase.playing,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) session.pause();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Change options',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              SoundEffects.play(SoundEffect.click);
              if (session.phase == MatchPhase.playing) {
                session.pause();
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            widget.game.title,
            style: const TextStyle(
              fontFamily: 'Lilita One',
              fontSize: 20,
              letterSpacing: .4,
            ),
          ),
          actions: [
            if (session.phase == MatchPhase.playing)
              IconButton(
                tooltip: 'Pause match',
                onPressed: () {
                  SoundEffects.play(SoundEffect.click);
                  session.pause();
                },
                icon: const Icon(Icons.pause_rounded),
              ),
          ],
        ),
        body: TapTussleBackdrop(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    _ScoreHud(
                      options: widget.options,
                      scores: session.scores,
                      matchLabel:
                          widget.game.matchLabel?.call(widget.options) ??
                          '2 PLAYERS',
                    ),
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRect(child: gameView),
                          if (session.phase != MatchPhase.playing)
                            _MatchOverlay(
                              phase: session.phase,
                              game: widget.game,
                              options: widget.options,
                              scores: session.scores,
                              winner: session.winner,
                              outcome: session.outcome,
                              resultDetails: session.resultDetails,
                              onPrimaryAction: () {
                                SoundEffects.play(SoundEffect.click);
                                if (session.phase == MatchPhase.paused) {
                                  session.resume();
                                } else {
                                  session.start();
                                }
                              },
                              onChangeOptions: () {
                                SoundEffects.play(SoundEffect.click);
                                Navigator.of(context).pop();
                              },
                              onBackToGames: () {
                                SoundEffects.play(SoundEffect.click);
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ScoreHud extends StatelessWidget {
  const _ScoreHud({
    required this.options,
    required this.scores,
    required this.matchLabel,
  });

  final MatchOptions options;
  final List<int> scores;
  final String matchLabel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    child: ArcadePanel(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      borderRadius: 18,
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${options.playerLabel(0)}  ${scores[0]}',
                style: const TextStyle(
                  fontFamily: 'Lilita One',
                  color: TapTussleColors.electricBlue,
                  fontSize: 23,
                  letterSpacing: .4,
                ),
              ),
            ),
          ),
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: TapTussleColors.gold.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: TapTussleColors.gold.withValues(alpha: .45),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  matchLabel,
                  maxLines: 1,
                  style: const TextStyle(
                    color: TapTussleColors.gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '${scores[1]}  ${options.playerLabel(1)}',
                style: const TextStyle(
                  fontFamily: 'Lilita One',
                  color: TapTussleColors.rivalRed,
                  fontSize: 23,
                  letterSpacing: .4,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MatchOverlay extends StatelessWidget {
  const _MatchOverlay({
    required this.phase,
    required this.game,
    required this.options,
    required this.scores,
    required this.winner,
    required this.outcome,
    required this.resultDetails,
    required this.onPrimaryAction,
    required this.onChangeOptions,
    required this.onBackToGames,
  });

  final MatchPhase phase;
  final MiniGame game;
  final MatchOptions options;
  final List<int> scores;
  final int? winner;
  final MatchOutcome? outcome;
  final String? resultDetails;
  final VoidCallback onPrimaryAction;
  final VoidCallback onChangeOptions;
  final VoidCallback onBackToGames;

  Color get accent {
    if (phase == MatchPhase.finished) {
      if (outcome == MatchOutcome.draw) return TapTussleColors.gold;
      return winner == 1
          ? TapTussleColors.rivalRed
          : TapTussleColors.electricBlue;
    }
    return phase == MatchPhase.paused
        ? TapTussleColors.gold
        : TapTussleColors.electricBlue;
  }

  String get title => switch (phase) {
    MatchPhase.ready =>
      options.mode == PlayMode.friend
          ? 'Take your sides'
          : 'Ready to challenge the bot?',
    MatchPhase.paused => 'Time out',
    MatchPhase.finished =>
      outcome == MatchOutcome.draw ? 'Draw!' : options.resultLabel(winner!),
    MatchPhase.playing => '',
  };

  String get details => switch (phase) {
    MatchPhase.ready => game.instructionsFor(options.mode),
    MatchPhase.paused => 'Catch your breath. Your match is right here.',
    MatchPhase.finished =>
      resultDetails ?? '${scores[0]} – ${scores[1]}  •  Another round?',
    MatchPhase.playing => '',
  };

  String get primaryLabel => switch (phase) {
    MatchPhase.ready => 'Start match',
    MatchPhase.paused => 'Resume match',
    _ => 'Play again',
  };

  String get primaryKey => switch (phase) {
    MatchPhase.ready => 'start-match',
    MatchPhase.paused => 'resume-match',
    MatchPhase.finished => 'play-again',
    MatchPhase.playing => 'match-action',
  };

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xE8061129),
    child: TapTussleBackdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ArcadePanel(
            accent: accent,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .14),
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: .25),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                  child: Icon(
                    phase == MatchPhase.finished
                        ? outcome == MatchOutcome.draw
                              ? Icons.handshake_rounded
                              : Icons.emoji_events_rounded
                        : phase == MatchPhase.paused
                        ? Icons.pause_rounded
                        : game.icon,
                    size: 40,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Lilita One',
                    color: accent,
                    fontSize: 34,
                    height: 1.05,
                    letterSpacing: .3,
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  details,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: TapTussleColors.mutedText,
                    height: 1.5,
                    fontSize: 15,
                  ),
                ),
                if (options.mode == PlayMode.bot) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: TapTussleColors.navy,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: TapTussleColors.panelBorder),
                    ),
                    child: Text(
                      '${options.botDifficulty!.label} bot',
                      style: const TextStyle(
                        color: TapTussleColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: ValueKey(primaryKey),
                    style: FilledButton.styleFrom(backgroundColor: accent),
                    onPressed: onPrimaryAction,
                    icon: Icon(
                      phase == MatchPhase.finished
                          ? Icons.replay_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    label: Text(primaryLabel),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        key: const ValueKey('change-options'),
                        onPressed: onChangeOptions,
                        child: const Text('Change options'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextButton(
                        key: const ValueKey('back-to-games'),
                        onPressed: onBackToGames,
                        child: const Text('Back to games'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
