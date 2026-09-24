import 'package:flutter/material.dart';

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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${widget.options.playerLabel(0)}  ${session.scores[0]}',
                              style: const TextStyle(
                                color: Color(0xFF9DF5CF),
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.game.matchLabel?.call(widget.options) ??
                                    '2 PLAYERS',
                                style: const TextStyle(
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                  color: Colors.white60,
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
                              '${session.scores[1]}  ${widget.options.playerLabel(1)}',
                              style: const TextStyle(
                                color: Color(0xFFFF968A),
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRect(child: gameView),
                        if (session.phase != MatchPhase.playing)
                          ColoredBox(
                            color: const Color(0xE8101A27),
                            child: Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      session.phase == MatchPhase.finished
                                          ? Icons.emoji_events_rounded
                                          : widget.game.icon,
                                      size: 48,
                                      color: const Color(0xFF9DF5CF),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      switch (session.phase) {
                                        MatchPhase.ready =>
                                          widget.options.mode == PlayMode.friend
                                              ? 'Take your sides'
                                              : 'Ready to challenge the bot?',
                                        MatchPhase.paused => 'Time out',
                                        MatchPhase.finished =>
                                          session.outcome == MatchOutcome.draw
                                              ? 'Draw!'
                                              : widget.options.resultLabel(
                                                  session.winner!,
                                                ),
                                        MatchPhase.playing => '',
                                      },
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      switch (session.phase) {
                                        MatchPhase.ready =>
                                          widget.game.instructionsFor(
                                            widget.options.mode,
                                          ),
                                        MatchPhase.paused =>
                                          'Catch your breath. Your match is right here.',
                                        MatchPhase.finished =>
                                          session.resultDetails ??
                                              '${session.scores[0]} – ${session.scores[1]}  •  Another round?',
                                        MatchPhase.playing => '',
                                      },
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        height: 1.6,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 28),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        key: ValueKey(switch (session.phase) {
                                          MatchPhase.ready => 'start-match',
                                          MatchPhase.paused => 'resume-match',
                                          MatchPhase.finished => 'play-again',
                                          MatchPhase.playing => 'match-action',
                                        }),
                                        onPressed: () {
                                          SoundEffects.play(SoundEffect.click);
                                          if (session.phase ==
                                              MatchPhase.paused) {
                                            session.resume();
                                          } else {
                                            session.start();
                                          }
                                        },
                                        child: Text(switch (session.phase) {
                                          MatchPhase.ready => 'Start match',
                                          MatchPhase.paused => 'Resume match',
                                          _ => 'Play again',
                                        }),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (widget.options.mode == PlayMode.bot)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          '${widget.options.botDifficulty!.label} bot',
                                          style: const TextStyle(
                                            color: Colors.white60,
                                          ),
                                        ),
                                      ),
                                    TextButton(
                                      key: const ValueKey('change-options'),
                                      onPressed: () {
                                        SoundEffects.play(SoundEffect.click);
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('Change options'),
                                    ),
                                    TextButton(
                                      key: const ValueKey('back-to-games'),
                                      onPressed: () {
                                        SoundEffects.play(SoundEffect.click);
                                        Navigator.of(
                                          context,
                                        ).popUntil((route) => route.isFirst);
                                      },
                                      child: const Text('Back to games'),
                                    ),
                                  ],
                                ),
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
        ),
      ),
    ),
  );
}
