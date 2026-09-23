import 'package:flutter/material.dart';

import '../../core/match_session.dart';
import '../../core/mini_game.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({
    required this.game,
    required this.winningScore,
    super.key,
  });
  final MiniGame game;
  final int winningScore;
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with WidgetsBindingObserver {
  final session = MatchSession();
  late final Widget gameView;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    gameView = widget.game.build(session, widget.winningScore);
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
            tooltip: 'Back to games',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
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
                onPressed: session.pause,
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
                              'P1  ${session.scores[0]}',
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
                                widget.game.matchLabel?.call(
                                      widget.winningScore,
                                    ) ??
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
                              '${session.scores[1]}  P2',
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
                                        MatchPhase.ready => 'Take your sides',
                                        MatchPhase.paused => 'Time out',
                                        MatchPhase.finished =>
                                          'Player ${session.winner! + 1} wins!',
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
                                          widget.game.instructions,
                                        MatchPhase.paused =>
                                          'Catch your breath. Your match is right here.',
                                        MatchPhase.finished =>
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
                                        onPressed:
                                            session.phase == MatchPhase.paused
                                            ? session.resume
                                            : session.start,
                                        child: Text(switch (session.phase) {
                                          MatchPhase.ready => 'Start match',
                                          MatchPhase.paused => 'Resume match',
                                          _ => 'Play again',
                                        }),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
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
