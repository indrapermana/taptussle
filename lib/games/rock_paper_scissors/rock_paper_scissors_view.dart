import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/haptic_service.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
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
    controller = RockPaperScissorsController(session: widget.session)
      ..addListener(_playEffects);
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
    required this.enabled,
    required this.onChoice,
  });

  final String playerLabel;
  final bool enabled;
  final ValueChanged<RockPaperScissorsChoice> onChoice;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        '${playerLabel.toUpperCase()}, CHOOSE',
        key: const ValueKey('rps-status'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Lilita One',
          fontSize: 26,
          letterSpacing: .8,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Your choice locks immediately',
        style: TextStyle(color: TapTussleColors.mutedText),
      ),
      const SizedBox(height: 26),
      for (final choice in RockPaperScissorsChoice.values) ...[
        _ChoiceButton(
          choice: choice,
          enabled: enabled,
          onPressed: () => onChoice(choice),
        ),
        const SizedBox(height: 12),
      ],
    ],
  );
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.choice,
    required this.enabled,
    required this.onPressed,
  });

  final RockPaperScissorsChoice choice;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      key: ValueKey('rps-choice-${choice.name}'),
      onPressed: enabled ? onPressed : null,
      icon: Icon(_choiceIcon(choice), size: 28),
      label: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(_choiceLabel(choice)),
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
            const Icon(
              Icons.visibility_off_rounded,
              color: TapTussleColors.gold,
              size: 42,
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

class _RevealPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final result = switch (round.outcome) {
      RockPaperScissorsRoundOutcome.playerOneWin => '${labels[0]} wins!',
      RockPaperScissorsRoundOutcome.playerTwoWin => '${labels[1]} wins!',
      RockPaperScissorsRoundOutcome.draw => 'Draw!',
    };
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          result.toUpperCase(),
          key: const ValueKey('rps-status'),
          style: const TextStyle(
            color: TapTussleColors.gold,
            fontFamily: 'Lilita One',
            fontSize: 30,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _RevealedChoice(
                label: labels[0],
                choice: round.playerOneChoice,
                color: TapTussleColors.electricBlue,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('VS', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: _RevealedChoice(
                label: labels[1],
                choice: round.playerTwoChoice,
                color: TapTussleColors.rivalRed,
              ),
            ),
          ],
        ),
        if (!matchFinished) ...[
          const SizedBox(height: 28),
          FilledButton.icon(
            key: const ValueKey('rps-next-round'),
            onPressed: onNextRound,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('NEXT ROUND'),
          ),
        ],
      ],
    );
  }
}

class _RevealedChoice extends StatelessWidget {
  const _RevealedChoice({
    required this.label,
    required this.choice,
    required this.color,
  });

  final String label;
  final RockPaperScissorsChoice choice;
  final Color color;

  @override
  Widget build(BuildContext context) => ArcadePanel(
    accent: color,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
    child: Column(
      children: [
        Icon(_choiceIcon(choice), color: color, size: 48),
        const SizedBox(height: 10),
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
  );
}

String _choiceLabel(RockPaperScissorsChoice choice) => switch (choice) {
  RockPaperScissorsChoice.rock => 'ROCK',
  RockPaperScissorsChoice.paper => 'PAPER',
  RockPaperScissorsChoice.scissors => 'SCISSORS',
};

IconData _choiceIcon(RockPaperScissorsChoice choice) => switch (choice) {
  RockPaperScissorsChoice.rock => Icons.sports_mma_rounded,
  RockPaperScissorsChoice.paper => Icons.back_hand_rounded,
  RockPaperScissorsChoice.scissors => Icons.content_cut_rounded,
};
