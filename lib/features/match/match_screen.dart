import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/match_session.dart';
import '../../core/match_options.dart';
import '../../core/app_settings.dart';
import '../../core/mini_game.dart';
import '../../core/sound_service.dart';
import '../../core/game_record_repository.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({
    required this.game,
    required this.options,
    this.resolution = ResolutionPreset.native,
    this.frameRate = FrameRatePreset.fps60,
    this.startImmediately = false,
    this.recordRepository,
    this.recordVariant,
    super.key,
  });
  final MiniGame game;
  final MatchOptions options;
  final ResolutionPreset resolution;
  final FrameRatePreset frameRate;
  final bool startImmediately;
  final GameRecordRepository? recordRepository;
  final String? recordVariant;
  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> with WidgetsBindingObserver {
  late final MatchSession session;
  late final Widget gameView;
  var _observedRound = 0;
  var _observedPhase = MatchPhase.ready;
  var _recordedRound = 0;
  GameRecordBests? _recordBests;
  bool _recordSaving = false;
  bool _isNewOverallBest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session = MatchSession(options: widget.options);
    session.addListener(_playSessionEffects);
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

  void _playSessionEffects() {
    if (session.round != _observedRound &&
        session.phase == MatchPhase.playing) {
      _observedRound = session.round;
      _recordBests = null;
      _recordSaving = false;
      _isNewOverallBest = false;
      SoundEffects.play(SoundEffect.roundStart);
    }
    if (_observedPhase != MatchPhase.finished &&
        session.phase == MatchPhase.finished) {
      SoundEffects.play(
        resultEffectForMatch(
          options: widget.options,
          outcome: session.outcome,
          winner: session.winner,
        ),
      );
      _saveRecordIfAvailable();
    }
    _observedPhase = session.phase;
  }

  Future<void> _saveRecordIfAvailable() async {
    final repository = widget.recordRepository;
    final definition = widget.game.recordDefinition;
    final metrics = session.recordMetrics;
    if (repository == null ||
        definition == null ||
        metrics == null ||
        widget.options.mode != PlayMode.solo ||
        _recordedRound == session.round) {
      return;
    }
    _recordedRound = session.round;
    final key = GameRecordKey(
      gameId: widget.game.id,
      recordType: definition.recordType,
      variant: widget.recordVariant ?? widget.options.difficulty.name,
    );
    final previousBest = repository.bestRecord(
      key: key,
      definition: definition,
    );
    _recordSaving = true;
    _isNewOverallBest =
        previousBest == null ||
        _metricsAreBetter(definition, metrics, previousBest.record.metrics);
    try {
      await repository.addRecord(
        definition: definition,
        record: GameRecord(
          key: key,
          completedAt: DateTime.now(),
          metrics: metrics,
        ),
      );
      if (mounted) {
        setState(() {
          _recordBests = repository.bests(key: key, definition: definition);
          _recordSaving = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _recordSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this record.')),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) session.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.removeListener(_playSessionEffects);
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
              SoundEffects.play(SoundEffect.uiBack);
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
                  SoundEffects.play(SoundEffect.uiTap);
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
                    if (session.phase != MatchPhase.finished)
                      _ScoreHud(
                        options: widget.options,
                        scores: session.scores,
                        matchLabel:
                            widget.game.matchLabel?.call(widget.options) ??
                            '${widget.options.participants.length} ${widget.options.participants.length == 1 ? 'PLAYER' : 'PLAYERS'}',
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
                              standings: session.standings,
                              resultDetails: session.resultDetails,
                              recordMetrics: session.recordMetrics,
                              recordBests: _recordBests,
                              recordSaving: _recordSaving,
                              isNewOverallBest: _isNewOverallBest,
                              onPrimaryAction: () {
                                SoundEffects.play(SoundEffect.uiConfirm);
                                if (session.phase == MatchPhase.paused) {
                                  session.resume();
                                } else {
                                  session.start();
                                }
                              },
                              onChangeOptions: () {
                                SoundEffects.play(SoundEffect.uiBack);
                                Navigator.of(context).pop();
                              },
                              onBackToGames: () {
                                SoundEffects.play(SoundEffect.uiBack);
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
      child: options.participants.length == 2
          ? _twoPlayerHud()
          : _flexibleParticipantHud(),
    ),
  );

  Widget _twoPlayerHud() => Row(
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
      Flexible(child: _MatchLabel(label: matchLabel)),
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
  );

  Widget _flexibleParticipantHud() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _MatchLabel(label: matchLabel),
      const SizedBox(height: 8),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 4,
        children: [
          for (final entry in options.participants.indexed)
            Text(
              '${entry.$2.displayName}  ${entry.$1 < scores.length ? scores[entry.$1] : 0}',
              style: TextStyle(
                fontFamily: 'Lilita One',
                color: _participantHudColors[entry.$1],
                fontSize: 17,
              ),
            ),
        ],
      ),
    ],
  );

  static const _participantHudColors = [
    Color(0xFF9DF5CF),
    Color(0xFFFF968A),
    TapTussleColors.gold,
    Color(0xFFB388FF),
  ];
}

class _MatchLabel extends StatelessWidget {
  const _MatchLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 10),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: TapTussleColors.gold.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: TapTussleColors.gold.withValues(alpha: .45)),
    ),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        style: const TextStyle(
          color: TapTussleColors.gold,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
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
    required this.standings,
    required this.resultDetails,
    required this.recordMetrics,
    required this.recordBests,
    required this.recordSaving,
    required this.isNewOverallBest,
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
  final List<int> standings;
  final String? resultDetails;
  final Map<String, num>? recordMetrics;
  final GameRecordBests? recordBests;
  final bool recordSaving;
  final bool isNewOverallBest;
  final VoidCallback onPrimaryAction;
  final VoidCallback onChangeOptions;
  final VoidCallback onBackToGames;

  Color get accent {
    if (phase == MatchPhase.finished) {
      if (outcome == MatchOutcome.draw) return TapTussleColors.gold;
      if (outcome == MatchOutcome.completed) {
        return TapTussleColors.electricBlue;
      }
      return _resultColors[winner!];
    }
    return phase == MatchPhase.paused
        ? TapTussleColors.gold
        : TapTussleColors.electricBlue;
  }

  String get title => switch (phase) {
    MatchPhase.ready => switch (options.mode) {
      PlayMode.solo => 'Ready to play?',
      PlayMode.friend => 'Take your sides',
      PlayMode.bot => 'Ready to challenge the bot?',
    },
    MatchPhase.paused => 'Time out',
    MatchPhase.finished => switch (outcome!) {
      MatchOutcome.winner => options.resultLabel(winner!),
      MatchOutcome.draw => 'Draw!',
      MatchOutcome.completed => 'Complete!',
    },
    MatchPhase.playing => '',
  };

  String get details => switch (phase) {
    MatchPhase.ready => game.instructionsFor(options.mode),
    MatchPhase.paused => 'Catch your breath. Your match is right here.',
    MatchPhase.finished => resultDetails ?? '',
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

  IconData get _resultIcon => switch (outcome) {
    MatchOutcome.draw => Icons.handshake_rounded,
    MatchOutcome.completed => Icons.check_circle_rounded,
    _ => Icons.emoji_events_rounded,
  };

  static const _resultColors = [
    Color(0xFF9DF5CF),
    Color(0xFFFF968A),
    TapTussleColors.gold,
    Color(0xFFB388FF),
  ];

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
                        ? _resultIcon
                        : phase == MatchPhase.paused
                        ? Icons.pause_rounded
                        : game.icon,
                    size: 40,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  liveRegion: phase == MatchPhase.finished,
                  child: Text(
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
                ),
                if (phase == MatchPhase.finished) ...[
                  const SizedBox(height: 16),
                  _FinishedResultSummary(
                    options: options,
                    scores: scores,
                    winner: winner,
                    outcome: outcome!,
                    standings: standings,
                  ),
                ],
                if (details.isNotEmpty) ...[
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
                ],
                if (phase == MatchPhase.finished &&
                    game.recordDefinition != null &&
                    recordMetrics != null) ...[
                  const SizedBox(height: 16),
                  _RecordResultPanel(
                    definition: game.recordDefinition!,
                    current: recordMetrics!,
                    bests: recordBests,
                    saving: recordSaving,
                    isNewOverallBest: isNewOverallBest,
                  ),
                ],
                if (options.mode == PlayMode.bot &&
                    options.botDifficulty != null) ...[
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
                if (phase == MatchPhase.finished) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey('change-options'),
                      onPressed: onChangeOptions,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Change options'),
                    ),
                  ),
                  const SizedBox(height: 2),
                  TextButton.icon(
                    key: const ValueKey('back-to-games'),
                    onPressed: onBackToGames,
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Games'),
                  ),
                ] else ...[
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
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _FinishedResultSummary extends StatelessWidget {
  const _FinishedResultSummary({
    required this.options,
    required this.scores,
    required this.winner,
    required this.outcome,
    required this.standings,
  });

  final MatchOptions options;
  final List<int> scores;
  final int? winner;
  final MatchOutcome outcome;
  final List<int> standings;

  @override
  Widget build(BuildContext context) {
    if (options.participants.length <= 2) {
      return Row(
        key: const ValueKey('result-score-cards'),
        children: [
          for (final entry in options.participants.indexed) ...[
            if (entry.$1 > 0) const SizedBox(width: 10),
            Expanded(
              child: _ResultPlayerCard(
                index: entry.$1,
                participant: entry.$2,
                score: entry.$1 < scores.length ? scores[entry.$1] : 0,
                isWinner: winner == entry.$1,
                isDraw: outcome == MatchOutcome.draw,
              ),
            ),
          ],
        ],
      );
    }

    final order = standings.isNotEmpty
        ? List<int>.of(standings)
        : List<int>.generate(options.participants.length, (index) => index);
    if (standings.isEmpty) {
      order.sort((left, right) {
        final scoreComparison = scores[right].compareTo(scores[left]);
        return scoreComparison != 0 ? scoreComparison : left.compareTo(right);
      });
    }
    return Semantics(
      container: true,
      label: standings.isNotEmpty ? 'Final standings' : 'Final scores',
      child: Container(
        key: const ValueKey('result-standings'),
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: TapTussleColors.midnight.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TapTussleColors.panelBorder),
        ),
        child: Column(
          children: [
            Text(
              standings.isNotEmpty ? 'FINAL STANDINGS' : 'FINAL SCORES',
              style: const TextStyle(
                color: TapTussleColors.mutedText,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 7),
            for (final entry in order.indexed) ...[
              _StandingRow(
                place: entry.$1 + 1,
                participant: options.participants[entry.$2],
                score: entry.$2 < scores.length ? scores[entry.$2] : 0,
                isWinner: winner == entry.$2,
              ),
              if (entry.$1 < order.length - 1) const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultPlayerCard extends StatelessWidget {
  const _ResultPlayerCard({
    required this.index,
    required this.participant,
    required this.score,
    required this.isWinner,
    required this.isDraw,
  });

  final int index;
  final MatchParticipant participant;
  final int score;
  final bool isWinner;
  final bool isDraw;

  @override
  Widget build(BuildContext context) {
    final color = _participantResultColor(participant.color);
    return Semantics(
      container: true,
      label:
          '${participant.displayName}, score $score${isWinner
              ? ', winner'
              : isDraw
              ? ', draw'
              : ''}',
      excludeSemantics: true,
      child: Container(
        key: ValueKey('result-score-card-$index'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isWinner ? .2 : .1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: isWinner ? 2.5 : 1),
          boxShadow: isWinner
              ? [BoxShadow(color: color.withValues(alpha: .22), blurRadius: 16)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isWinner
                  ? Icons.emoji_events_rounded
                  : _resultTokenIcon(participant.token),
              color: color,
              size: 27,
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                participant.displayName,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$score',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Lilita One',
                fontSize: 32,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.place,
    required this.participant,
    required this.score,
    required this.isWinner,
  });

  final int place;
  final MatchParticipant participant;
  final int score;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final color = _participantResultColor(participant.color);
    return Semantics(
      container: true,
      label: 'Place $place, ${participant.displayName}, score $score',
      excludeSemantics: true,
      child: Container(
        key: ValueKey('result-place-$place'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isWinner
              ? color.withValues(alpha: .16)
              : Colors.white.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isWinner ? color : Colors.white12,
            width: isWinner ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _placeColor(place).withValues(alpha: .18),
                border: Border.all(color: _placeColor(place)),
              ),
              child: Text(
                '$place',
                style: TextStyle(
                  color: _placeColor(place),
                  fontFamily: 'Lilita One',
                  fontSize: 17,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Icon(_resultTokenIcon(participant.token), color: color, size: 21),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                participant.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$score',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Lilita One',
                fontSize: 23,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _participantResultColor(ParticipantColor color) => switch (color) {
  ParticipantColor.mint => const Color(0xFF9DF5CF),
  ParticipantColor.coral => const Color(0xFFFF968A),
  ParticipantColor.gold => TapTussleColors.gold,
  ParticipantColor.violet => const Color(0xFFB388FF),
};

Color _placeColor(int place) => switch (place) {
  1 => TapTussleColors.gold,
  2 => const Color(0xFFDCE8F5),
  3 => const Color(0xFFD9955E),
  _ => TapTussleColors.mutedText,
};

IconData _resultTokenIcon(ParticipantToken token) => switch (token) {
  ParticipantToken.circle => Icons.circle_rounded,
  ParticipantToken.diamond => Icons.diamond_rounded,
  ParticipantToken.triangle => Icons.change_history_rounded,
  ParticipantToken.star => Icons.star_rounded,
};

class _RecordResultPanel extends StatelessWidget {
  const _RecordResultPanel({
    required this.definition,
    required this.current,
    required this.bests,
    required this.saving,
    required this.isNewOverallBest,
  });

  final GameRecordDefinition definition;
  final Map<String, num> current;
  final GameRecordBests? bests;
  final bool saving;
  final bool isNewOverallBest;

  @override
  Widget build(BuildContext context) {
    final primary = definition.primaryMetric;
    return Container(
      key: const ValueKey('record-result-panel'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TapTussleColors.navy.withValues(alpha: .78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TapTussleColors.panelBorder),
      ),
      child: Column(
        children: [
          Text(
            isNewOverallBest ? 'NEW OVERALL BEST' : 'THIS RUN',
            key: const ValueKey('record-result-status'),
            style: TextStyle(
              color: isNewOverallBest
                  ? TapTussleColors.gold
                  : TapTussleColors.electricBlue,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _recordMetricLine(definition, current),
            key: const ValueKey('record-current-metrics'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (saving)
            const Text(
              'Saving record…',
              style: TextStyle(color: TapTussleColors.mutedText, fontSize: 11),
            )
          else
            Row(
              children: [
                for (final entry in [
                  ('DAILY', bests?.daily),
                  ('WEEKLY', bests?.weekly),
                  ('OVERALL', bests?.overall),
                ])
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          entry.$1,
                          style: const TextStyle(
                            color: TapTussleColors.mutedText,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          entry.$2 == null
                              ? '—'
                              : _formatRecordMetric(
                                  primary,
                                  entry.$2!.record.metrics[primary.id]!,
                                ),
                          key: ValueKey(
                            'result-record-${entry.$1.toLowerCase()}',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (entry.$2 != null &&
                            definition.tieBreakers.isNotEmpty)
                          Text(
                            _formatRecordMetric(
                              definition.tieBreakers.first,
                              entry.$2!.record.metrics[definition
                                  .tieBreakers
                                  .first
                                  .id]!,
                            ),
                            style: const TextStyle(
                              color: TapTussleColors.mutedText,
                              fontSize: 9,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

bool _metricsAreBetter(
  GameRecordDefinition definition,
  Map<String, num> candidate,
  Map<String, num> currentBest,
) {
  for (final metric in definition.metrics) {
    final comparison = candidate[metric.id]!.compareTo(currentBest[metric.id]!);
    if (comparison == 0) continue;
    return metric.sortOrder == RecordSortOrder.higherIsBetter
        ? comparison > 0
        : comparison < 0;
  }
  return false;
}

String _recordMetricLine(
  GameRecordDefinition definition,
  Map<String, num> metrics,
) => definition.metrics
    .map(
      (metric) =>
          '${metric.label} ${_formatRecordMetric(metric, metrics[metric.id]!)}',
    )
    .join('  •  ');

String _formatRecordMetric(RecordMetricDefinition definition, num value) =>
    switch (definition.format) {
      RecordMetricFormat.integer => value.round().toString(),
      RecordMetricFormat.duration => _formatRecordDuration(value.round()),
    };

String _formatRecordDuration(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  if (minutes > 0) return '$minutes:${seconds.toString().padLeft(2, '0')}';
  return '${(milliseconds / 1000).toStringAsFixed(1)}s';
}
