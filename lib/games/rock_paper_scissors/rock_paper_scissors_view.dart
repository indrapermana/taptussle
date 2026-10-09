import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/haptic_service.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'rock_paper_scissors_assets.dart';
import 'rock_paper_scissors_controller.dart';
import 'rock_paper_scissors_model.dart';

class RockPaperScissorsView extends StatefulWidget {
  const RockPaperScissorsView({
    required this.session,
    required this.options,
    super.key,
  });

  final MatchSession session;
  final MatchOptions options;

  @override
  State<RockPaperScissorsView> createState() => _RockPaperScissorsViewState();
}

class _RockPaperScissorsViewState extends State<RockPaperScissorsView> {
  late final RockPaperScissorsController controller;
  var _observedPhase = RockPaperScissorsRoundPhase.choosing;
  var _observedRoundCount = 0;

  @override
  void initState() {
    super.initState();
    controller = RockPaperScissorsController(
      session: widget.session,
      finalRevealDelay: const Duration(milliseconds: 1400),
    )..addListener(_playEffects);
  }

  void _playEffects() {
    final phase = controller.phase;
    final roundCount = controller.model.roundCount;
    if (roundCount > _observedRoundCount) {
      _observedRoundCount = roundCount;
      SoundEffects.play(SoundEffect.roundReveal);
      HapticEffects.paddleHit();
      if (!controller.model.isFinished) {
        final outcome = controller.model.lastRound!.outcome;
        final scorer = switch (outcome) {
          RockPaperScissorsRoundOutcome.playerOneWin => 0,
          RockPaperScissorsRoundOutcome.playerTwoWin => 1,
          RockPaperScissorsRoundOutcome.draw => null,
        };
        if (scorer != null) {
          SoundEffects.play(scoreEffectForParticipant(widget.options, scorer));
        }
      }
    } else if (phase != _observedPhase) {
      switch (phase) {
        case RockPaperScissorsRoundPhase.handoff:
        case RockPaperScissorsRoundPhase.botThinking:
          SoundEffects.play(SoundEffect.uiConfirm);
          HapticEffects.preview();
        case RockPaperScissorsRoundPhase.choosing:
          SoundEffects.play(
            _observedPhase == RockPaperScissorsRoundPhase.reveal
                ? SoundEffect.roundStart
                : SoundEffect.uiTap,
          );
        case RockPaperScissorsRoundPhase.reveal:
          break;
      }
    }
    _observedPhase = phase;
  }

  @override
  void dispose() {
    controller.removeListener(_playEffects);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RockPaperScissorsBoard(
    controller: controller,
    playerLabels: [
      widget.options.playerLabel(0),
      widget.options.playerLabel(1),
    ],
  );
}

class RockPaperScissorsBoard extends StatelessWidget {
  const RockPaperScissorsBoard({
    required this.controller,
    required this.playerLabels,
    super.key,
  }) : assert(playerLabels.length == 2);

  final RockPaperScissorsController controller;
  final List<String> playerLabels;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => ColoredBox(
      color: const Color(0xFF101A27),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            children: [
              _Scoreboard(
                labels: playerLabels,
                scores: controller.model.scores,
                winningScore: controller.model.winningScore,
              ),
              const SizedBox(height: 18),
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _content() => switch (controller.phase) {
    RockPaperScissorsRoundPhase.choosing => _ChoicePanel(
      playerLabel: playerLabels[controller.activePlayer],
      warm: controller.activePlayer == 1,
      enabled: controller.acceptsChoice,
      onChoice: controller.selectChoice,
    ),
    RockPaperScissorsRoundPhase.handoff => _HandoffPanel(
      playerLabel: playerLabels[controller.activePlayer],
      onReady: controller.confirmHandoff,
    ),
    RockPaperScissorsRoundPhase.botThinking => const _WaitingPanel(),
    RockPaperScissorsRoundPhase.reveal => _RevealPanel(
      round: controller.model.lastRound!,
      labels: playerLabels,
      matchFinished: controller.model.isFinished,
      onNextRound: controller.startNextRound,
    ),
  };
}

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({
    required this.labels,
    required this.scores,
    required this.winningScore,
  });

  final List<String> labels;
  final List<int> scores;
  final int winningScore;

  @override
  Widget build(BuildContext context) => ArcadePanel(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: _score(labels[0], scores[0], TapTussleColors.electricBlue),
        ),
        Text(
          'FIRST TO $winningScore',
          style: const TextStyle(
            color: TapTussleColors.gold,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        Expanded(child: _score(labels[1], scores[1], TapTussleColors.rivalRed)),
      ],
    ),
  );

  Widget _score(String label, int score, Color color) => Column(
    children: [
      Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
      Text(
        '$score',
        style: TextStyle(color: color, fontFamily: 'Lilita One', fontSize: 28),
      ),
    ],
  );
}

class _ChoicePanel extends StatelessWidget {
  const _ChoicePanel({
    required this.playerLabel,
    required this.warm,
    required this.enabled,
    required this.onChoice,
  });

  final String playerLabel;
  final bool warm;
  final bool enabled;
  final ValueChanged<RockPaperScissorsChoice> onChoice;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final choiceHeight = (constraints.maxHeight - 100).clamp(100.0, 210.0);
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${playerLabel.toUpperCase()}, CHOOSE',
              key: const ValueKey('rps-status'),
              textAlign: TextAlign.center,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Lilita One',
                fontSize: 26,
                letterSpacing: .8,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Your choice locks immediately',
              maxLines: 1,
              style: TextStyle(color: TapTussleColors.mutedText),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: choiceHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final choice in RockPaperScissorsChoice.values) ...[
                  if (choice != RockPaperScissorsChoice.rock)
                    const SizedBox(width: 8),
                  Expanded(
                    child: _ChoiceButton(
                      choice: choice,
                      warm: warm,
                      enabled: enabled,
                      onPressed: () => onChoice(choice),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.choice,
    required this.warm,
    required this.enabled,
    required this.onPressed,
  });

  final RockPaperScissorsChoice choice;
  final bool warm;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Choose ${_choiceLabel(choice).toLowerCase()}',
    child: FilledButton(
      key: ValueKey('rps-choice-${choice.name}'),
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.fromLTRB(5, 8, 5, 10),
        backgroundColor: warm
            ? TapTussleColors.rivalRed.withValues(alpha: .28)
            : TapTussleColors.electricBlue.withValues(alpha: .28),
      ),
      child: SizedBox.expand(
        child: Column(
          children: [
            Expanded(
              child: Image.asset(
                RockPaperScissorsAssets.choice(choice, warm: warm),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(fit: BoxFit.scaleDown, child: Text(_choiceLabel(choice))),
          ],
        ),
      ),
    ),
  );
}

class _HandoffPanel extends StatelessWidget {
  const _HandoffPanel({required this.playerLabel, required this.onReady});

  final String playerLabel;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      child: ArcadePanel(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              RockPaperScissorsAssets.choiceLocked,
              key: const ValueKey('rps-choice-locked-art'),
              width: 112,
              height: 112,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 10),
            const Text(
              'CHOICE LOCKED',
              key: ValueKey('rps-status'),
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Lilita One',
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('rps-handoff-ready'),
              onPressed: onReady,
              icon: const Icon(Icons.check_rounded),
              label: Text('$playerLabel IS READY'),
            ),
            const SizedBox(height: 14),
            Text(
              'Pass the device to $playerLabel.\nKeep the screen hidden until they are ready.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: TapTussleColors.mutedText),
            ),
          ],
        ),
      ),
    ),
  );
}

class _WaitingPanel extends StatelessWidget {
  const _WaitingPanel();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 20),
        Text(
          'BOT IS THINKING…',
          key: ValueKey('rps-status'),
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Lilita One',
            fontSize: 25,
          ),
        ),
      ],
    ),
  );
}

class _RevealPanel extends StatefulWidget {
  const _RevealPanel({
    required this.round,
    required this.labels,
    required this.matchFinished,
    required this.onNextRound,
  });

  final RockPaperScissorsRound round;
  final List<String> labels;
  final bool matchFinished;
  final VoidCallback onNextRound;

  @override
  State<_RevealPanel> createState() => _RevealPanelState();
}

class _RevealPanelState extends State<_RevealPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final round = widget.round;
    final result = switch (round.outcome) {
      RockPaperScissorsRoundOutcome.playerOneWin => '${widget.labels[0]} wins!',
      RockPaperScissorsRoundOutcome.playerTwoWin => '${widget.labels[1]} wins!',
      RockPaperScissorsRoundOutcome.draw => 'Draw!',
    };
    final winner = switch (round.outcome) {
      RockPaperScissorsRoundOutcome.playerOneWin => 0,
      RockPaperScissorsRoundOutcome.playerTwoWin => 1,
      RockPaperScissorsRoundOutcome.draw => null,
    };
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final choicesProgress = Curves.easeOutCubic.transform(
          (_animation.value / .55).clamp(0.0, 1.0),
        );
        final resultProgress = Curves.easeOutBack.transform(
          ((_animation.value - .42) / .58).clamp(0.0, 1.0),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: constraints.maxWidth,
                height: 430,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 90,
                      child: Opacity(
                        opacity: resultProgress.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: .7 + (.3 * resultProgress),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              children: [
                                Text(
                                  result.toUpperCase(),
                                  key: const ValueKey('rps-status'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: TapTussleColors.gold,
                                    fontFamily: 'Lilita One',
                                    fontSize: 30,
                                  ),
                                ),
                                Text(
                                  winner == null
                                      ? 'NO POINT — PLAY AGAIN'
                                      : '+1 POINT',
                                  key: const ValueKey('rps-round-points'),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 90,
                      left: 0,
                      right: 0,
                      bottom: widget.matchFinished ? 0 : 62,
                      child: Transform.scale(
                        scale: choicesProgress,
                        child: Row(
                          children: [
                            Expanded(
                              child: _RevealedChoice(
                                label: widget.labels[0],
                                choice: round.playerOneChoice,
                                warm: false,
                                winner: winner == 0,
                                dimmed: winner == 1,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'VS',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                            Expanded(
                              child: _RevealedChoice(
                                label: widget.labels[1],
                                choice: round.playerTwoChoice,
                                warm: true,
                                winner: winner == 1,
                                dimmed: winner == 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!widget.matchFinished) ...[
                      Positioned(
                        bottom: 0,
                        height: 52,
                        child: Opacity(
                          opacity: resultProgress.clamp(0.0, 1.0),
                          child: FilledButton.icon(
                            key: const ValueKey('rps-next-round'),
                            onPressed: widget.onNextRound,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('NEXT ROUND'),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RevealedChoice extends StatelessWidget {
  const _RevealedChoice({
    required this.label,
    required this.choice,
    required this.warm,
    required this.winner,
    required this.dimmed,
  });

  final String label;
  final RockPaperScissorsChoice choice;
  final bool warm;
  final bool winner;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final color = warm
        ? TapTussleColors.rivalRed
        : TapTussleColors.electricBlue;
    return Semantics(
      label:
          '$label chose ${_choiceLabel(choice).toLowerCase()}${winner ? ' and won the round' : ''}',
      container: true,
      excludeSemantics: true,
      child: AnimatedOpacity(
        key: ValueKey('rps-reveal-card-${warm ? 'warm' : 'cool'}'),
        duration: const Duration(milliseconds: 300),
        opacity: dimmed ? .52 : 1,
        child: ArcadePanel(
          accent: winner ? TapTussleColors.gold : color,
          padding: const EdgeInsets.fromLTRB(7, 7, 7, 12),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        RockPaperScissorsAssets.choice(choice, warm: warm),
                        key: ValueKey('rps-reveal-${warm ? 'warm' : 'cool'}'),
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    if (winner)
                      const DecoratedBox(
                        key: ValueKey('rps-round-winner'),
                        decoration: BoxDecoration(
                          color: TapTussleColors.gold,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(5),
                          child: Icon(
                            Icons.emoji_events_rounded,
                            color: Color(0xFF342300),
                            size: 21,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
              Text(
                _choiceLabel(choice),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _choiceLabel(RockPaperScissorsChoice choice) => switch (choice) {
  RockPaperScissorsChoice.rock => 'ROCK',
  RockPaperScissorsChoice.paper => 'PAPER',
  RockPaperScissorsChoice.scissors => 'SCISSORS',
};
