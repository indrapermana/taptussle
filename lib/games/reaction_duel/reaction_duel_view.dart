import 'package:flutter/material.dart';

import '../../core/haptic_service.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'reaction_duel_controller.dart';

class ReactionDuelView extends StatefulWidget {
  const ReactionDuelView({
    required this.session,
    required this.options,
    super.key,
  });
  final MatchSession session;
  final MatchOptions options;

  @override
  State<ReactionDuelView> createState() => _ReactionDuelViewState();
}

class _ReactionDuelViewState extends State<ReactionDuelView> {
  late final ReactionDuelController controller;
  int _reportedTotal = 0;
  int _round = -1;

  @override
  void initState() {
    super.initState();
    controller = ReactionDuelController(session: widget.session);
    widget.session.addListener(_syncSession);
    controller.addListener(_playEffects);
    _syncSession();
  }

  void _syncSession() {
    if (_round != widget.session.round) {
      _round = widget.session.round;
      _reportedTotal = 0;
      controller.resetMatch();
      return;
    }
    if (widget.session.phase == MatchPhase.playing &&
        controller.phase == ReactionPhase.waiting) {
      controller.resumeAfterPause();
    } else if (widget.session.phase == MatchPhase.paused) {
      controller.pause();
    }
  }

  void _playEffects() {
    final total = controller.scores[0] + controller.scores[1];
    if (total <= _reportedTotal) return;
    _reportedTotal = total;
    SoundEffects.play(
      widget.session.phase == MatchPhase.finished
          ? SoundEffect.result
          : SoundEffect.score,
    );
    HapticEffects.preview();
  }

  @override
  void dispose() {
    widget.session.removeListener(_syncSession);
    controller.removeListener(_playEffects);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            Expanded(
              child: _Zone(
                player: 1,
                controller: controller,
                upsideDown: true,
                options: widget.options,
              ),
            ),
            Expanded(
              child: _Zone(
                player: 0,
                controller: controller,
                options: widget.options,
              ),
            ),
          ],
        ),
        Center(child: _Signal(phase: controller.phase)),
      ],
    ),
  );
}

class _Zone extends StatelessWidget {
  const _Zone({
    required this.player,
    required this.controller,
    required this.options,
    this.upsideDown = false,
  });
  final int player;
  final ReactionDuelController controller;
  final MatchOptions options;
  final bool upsideDown;

  @override
  Widget build(BuildContext context) {
    final color = player == 0
        ? const Color(0xFF9DF5CF)
        : const Color(0xFFFF968A);
    final text = options.mode == PlayMode.bot && player == 1
        ? 'BOT'
        : 'PLAYER ${player + 1}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => controller.tap(player),
      child: ColoredBox(
        color: controller.phase == ReactionPhase.signal
            ? color.withValues(alpha: .2)
            : color.withValues(alpha: .06),
        child: Center(
          child: RotatedBox(
            quarterTurns: upsideDown ? 2 : 0,
            child: Text(
              text,
              style: TextStyle(
                color: color,
                letterSpacing: 3,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Signal extends StatelessWidget {
  const _Signal({required this.phase});
  final ReactionPhase phase;
  @override
  Widget build(BuildContext context) {
    final ready = phase == ReactionPhase.signal;
    return IgnorePointer(
      child: Container(
        width: 118,
        height: 118,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ready ? const Color(0xFF9DF5CF) : const Color(0xFF304253),
          boxShadow: ready
              ? const [BoxShadow(color: Color(0x889DF5CF), blurRadius: 28)]
              : null,
        ),
        child: Text(
          ready ? 'TAP!' : 'WAIT',
          style: const TextStyle(
            color: Color(0xFF142333),
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
