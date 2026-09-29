import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'snakes_and_ladders_controller.dart';
import 'snakes_and_ladders_model.dart';

class SnakesAndLaddersView extends StatefulWidget {
  const SnakesAndLaddersView({
    required this.session,
    required this.options,
    super.key,
  });

  final MatchSession session;
  final MatchOptions options;

  @override
  State<SnakesAndLaddersView> createState() => _SnakesAndLaddersViewState();
}

class _SnakesAndLaddersViewState extends State<SnakesAndLaddersView> {
  late final SnakesAndLaddersController controller;

  @override
  void initState() {
    super.initState();
    controller = SnakesAndLaddersController(session: widget.session);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SnakesAndLaddersBoard(controller: controller, options: widget.options);
}

class SnakesAndLaddersBoard extends StatelessWidget {
  const SnakesAndLaddersBoard({
    required this.controller,
    required this.options,
    super.key,
  });

  final SnakesAndLaddersController controller;
  final MatchOptions options;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => ColoredBox(
      color: const Color(0xFF101A27),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 650;
            return Padding(
              padding: EdgeInsets.fromLTRB(12, compact ? 8 : 14, 12, 14),
              child: Column(
                children: [
                  _TurnBanner(controller: controller, options: options),
                  SizedBox(height: compact ? 8 : 12),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _GameBoard(
                          positions: controller.displayPositions,
                          participants: options.participants,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 12),
                  _RollControls(controller: controller, options: options),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _TurnBanner extends StatelessWidget {
  const _TurnBanner({required this.controller, required this.options});

  final SnakesAndLaddersController controller;
  final MatchOptions options;

  @override
  Widget build(BuildContext context) {
    final player = controller.highlightedPlayer;
    final participant = options.participants[player];
    final status = controller.isAnimating
        ? '${participant.displayName.toUpperCase()} IS MOVING'
        : controller.isBotThinking
        ? '${participant.displayName.toUpperCase()} IS THINKING…'
        : '${participant.displayName.toUpperCase()}’S TURN';
    return ArcadePanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _Token(participant: participant, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status,
              key: const ValueKey('snakes-current-turn'),
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Lilita One',
                fontSize: 18,
                letterSpacing: .7,
              ),
            ),
          ),
          Text(
            controller.lastRoll == null
                ? 'ROLL —'
                : 'ROLL ${controller.lastRoll}',
            key: const ValueKey('snakes-last-roll'),
            style: const TextStyle(
              color: TapTussleColors.gold,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _GameBoard extends StatelessWidget {
  const _GameBoard({required this.positions, required this.participants});

  final List<int> positions;
  final List<MatchParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final visualSquares = SnakesAndLaddersModel.serpentineRows.reversed
        .expand((row) => row)
        .toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: TapTussleColors.electricBlue, width: 2),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x5500D9FF), blurRadius: 14)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: GridView.builder(
          key: const ValueKey('snakes-board'),
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8,
          ),
          itemCount: 64,
          itemBuilder: (context, index) {
            final square = visualSquares[index];
            final destination =
                SnakesAndLaddersModel.standardTransitions[square];
            final tokens = [
              for (final entry in positions.indexed)
                if (entry.$2 == square) entry.$1,
            ];
            return _BoardCell(
              square: square,
              destination: destination,
              tokenIndexes: tokens,
              participants: participants,
            );
          },
        ),
      ),
    );
  }
}

class _BoardCell extends StatelessWidget {
  const _BoardCell({
    required this.square,
    required this.destination,
    required this.tokenIndexes,
    required this.participants,
  });

  final int square;
  final int? destination;
  final List<int> tokenIndexes;
  final List<MatchParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final isLadder = destination != null && destination! > square;
    final base = ((square - 1) ~/ 8 + square) % 2 == 0;
    return Semantics(
      label: _semanticsLabel(isLadder),
      child: DecoratedBox(
        key: ValueKey('snakes-square-$square'),
        decoration: BoxDecoration(
          color: base ? const Color(0xFF173550) : const Color(0xFF214A63),
          border: Border.all(color: const Color(0x3329D8FF), width: .5),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 3,
              top: 2,
              child: Text(
                '$square',
                style: const TextStyle(
                  color: Color(0xFFB7C9D9),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (destination != null)
              Center(
                child: Text(
                  isLadder ? '↗' : '↘',
                  style: TextStyle(
                    color: isLadder
                        ? TapTussleColors.gold
                        : TapTussleColors.rivalRed,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomRight,
              child: Wrap(
                spacing: -3,
                runSpacing: -3,
                children: [
                  for (final player in tokenIndexes)
                    _Token(participant: participants[player], size: 13),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _semanticsLabel(bool isLadder) {
    final feature = destination == null
        ? ''
        : isLadder
        ? ', ladder to $destination'
        : ', snake to $destination';
    final occupants = tokenIndexes.isEmpty
        ? ''
        : ', ${tokenIndexes.map((index) => participants[index].displayName).join(', ')}';
    return 'Square $square$feature$occupants';
  }
}

class _RollControls extends StatelessWidget {
  const _RollControls({required this.controller, required this.options});

  final SnakesAndLaddersController controller;
  final MatchOptions options;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            for (final entry in options.participants.indexed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Token(participant: entry.$2, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.$2.displayName}: ${controller.displayPositions[entry.$1] == 0 ? 'START' : controller.displayPositions[entry.$1]}',
                    style: const TextStyle(
                      color: TapTussleColors.mutedText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      FilledButton.icon(
        key: const ValueKey('snakes-roll'),
        onPressed: controller.canRoll ? controller.roll : null,
        icon: const Icon(Icons.casino_rounded),
        label: Text(controller.isBotThinking ? 'WAIT' : 'ROLL'),
      ),
    ],
  );
}

class _Token extends StatelessWidget {
  const _Token({required this.participant, required this.size});

  final MatchParticipant participant;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _participantColor(participant.color),
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: size > 20 ? 2 : 1),
      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 3)],
    ),
    child: Icon(
      _tokenIcon(participant.token),
      color: Colors.white,
      size: size * .62,
    ),
  );
}

Color _participantColor(ParticipantColor color) => switch (color) {
  ParticipantColor.mint => TapTussleColors.electricBlue,
  ParticipantColor.coral => TapTussleColors.rivalRed,
  ParticipantColor.gold => TapTussleColors.gold,
  ParticipantColor.violet => const Color(0xFFB26CFF),
};

IconData _tokenIcon(ParticipantToken token) => switch (token) {
  ParticipantToken.circle => Icons.circle,
  ParticipantToken.diamond => Icons.diamond,
  ParticipantToken.triangle => Icons.change_history,
  ParticipantToken.star => Icons.star,
};
