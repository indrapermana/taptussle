import 'package:flutter/material.dart';

import '../../core/haptic_service.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'reaction_duel_controller.dart';

const _cool = Color(0xFF29C9FF);
const _warm = Color(0xFFFF7043);
const _gold = Color(0xFFFFD54F);
const _navy = Color(0xFF071525);

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
  final _reportedScores = [0, 0];
  var _reportedPhase = ReactionPhase.preparing;
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
      _reportedScores[0] = _reportedScores[1] = 0;
      controller.resetMatch();
      return;
    }
    if (widget.session.phase == MatchPhase.playing &&
        (controller.phase == ReactionPhase.preparing ||
            controller.phase == ReactionPhase.waiting)) {
      controller.resumeAfterPause();
    } else if (widget.session.phase == MatchPhase.paused) {
      controller.pause();
    }
  }

  void _playEffects() {
    final isFalseStart =
        controller.phase == ReactionPhase.resolving &&
        controller.lastResult?.outcome == ReactionRoundOutcome.falseStart;
    if (controller.phase != _reportedPhase) {
      _reportedPhase = controller.phase;
      if (controller.phase == ReactionPhase.signal) {
        SoundEffects.play(SoundEffect.countdownGo);
        HapticEffects.preview();
      } else if (isFalseStart) {
        SoundEffects.play(SoundEffect.uiInvalid);
      }
    }
    final total = controller.scores[0] + controller.scores[1];
    if (total <= _reportedTotal) return;
    _reportedTotal = total;
    if (widget.session.phase != MatchPhase.finished && !isFalseStart) {
      final scoringPlayer = controller.scores[0] > _reportedScores[0] ? 0 : 1;
      SoundEffects.play(
        scoreEffectForParticipant(widget.options, scoringPlayer),
      );
    }
    _reportedScores[0] = controller.scores[0];
    _reportedScores[1] = controller.scores[1];
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
    builder: (context, _) => ColoredBox(
      color: _navy,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Expanded(
                child: _ReactionZone(
                  key: const ValueKey('reaction-zone-1'),
                  player: 1,
                  controller: controller,
                  options: widget.options,
                  upsideDown: widget.options.mode == PlayMode.friend,
                  enabled: widget.options.mode != PlayMode.bot,
                ),
              ),
              Container(
                height: 2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_warm, _gold, _cool]),
                ),
              ),
              Expanded(
                child: _ReactionZone(
                  key: const ValueKey('reaction-zone-0'),
                  player: 0,
                  controller: controller,
                  options: widget.options,
                ),
              ),
            ],
          ),
          Center(child: _SignalCore(controller: controller)),
        ],
      ),
    ),
  );
}

class _ReactionZone extends StatelessWidget {
  const _ReactionZone({
    required this.player,
    required this.controller,
    required this.options,
    this.upsideDown = false,
    this.enabled = true,
    super.key,
  });

  final int player;
  final ReactionDuelController controller;
  final MatchOptions options;
  final bool upsideDown;
  final bool enabled;

  Color get color => player == 0 ? _cool : _warm;

  @override
  Widget build(BuildContext context) {
    final winner = controller.lastResult?.winner;
    final isWinner = winner == player;
    final isSignal = controller.phase == ReactionPhase.signal;
    final semantics = enabled
        ? '${options.playerLabel(player)} reaction zone. ${_statusText()}'
        : '${options.playerLabel(player)} reaction zone';

    return Semantics(
      button: enabled,
      enabled: enabled,
      label: semantics,
      liveRegion: controller.phase == ReactionPhase.resolving,
      excludeSemantics: true,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: enabled ? (_) => controller.tap(player) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: upsideDown ? Alignment.bottomCenter : Alignment.topCenter,
              end: upsideDown ? Alignment.topCenter : Alignment.bottomCenter,
              colors: [
                color.withValues(
                  alpha: isWinner
                      ? .34
                      : isSignal
                      ? .22
                      : .1,
                ),
                _navy.withValues(alpha: .94),
              ],
            ),
            boxShadow: isWinner
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: .45),
                      blurRadius: 46,
                      spreadRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: RotatedBox(
            quarterTurns: upsideDown ? 2 : 0,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          options.playerLabel(player).toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TweenAnimationBuilder<double>(
                        key: ValueKey(
                          'reaction-score-$player-${controller.scores[player]}',
                        ),
                        tween: Tween(begin: 1.3, end: 1),
                        duration: const Duration(milliseconds: 320),
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Text(
                          '${controller.scores[player]}',
                          style: TextStyle(
                            color: color,
                            fontFamily: 'Lilita One',
                            fontSize: 30,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _ZoneMessage(
                    player: player,
                    enabled: enabled,
                    controller: controller,
                    color: color,
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _statusText() {
    final result = controller.lastResult;
    if (result?.outcome == ReactionRoundOutcome.falseStart) {
      return result!.falseStarter == player
          ? 'Too early. False start.'
          : 'Point awarded.';
    }
    if (result?.outcome == ReactionRoundOutcome.tie) return 'Draw. Replay.';
    if (result?.winner == player) {
      final time = result?.reactionTimes[player];
      return 'Point won${time == null ? '' : ' in ${time.inMilliseconds} milliseconds'}.';
    }
    return switch (controller.phase) {
      ReactionPhase.preparing => 'Get ready.',
      ReactionPhase.waiting => 'Wait for the signal.',
      ReactionPhase.signal => 'Tap now.',
      ReactionPhase.resolving => 'Round complete.',
    };
  }
}

class _ZoneMessage extends StatelessWidget {
  const _ZoneMessage({
    required this.player,
    required this.enabled,
    required this.controller,
    required this.color,
  });

  final int player;
  final bool enabled;
  final ReactionDuelController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final result = controller.lastResult;
    var title = enabled ? 'TAP ANYWHERE' : 'BOT REACTION ZONE';
    String? value;
    String? caption;

    if (controller.phase == ReactionPhase.preparing) {
      title = 'GET READY';
    } else if (controller.phase == ReactionPhase.waiting) {
      caption = 'WAIT FOR THE SIGNAL';
    } else if (controller.phase == ReactionPhase.signal) {
      title = enabled ? 'TAP!' : 'BOT IS REACTING';
    } else if (result?.outcome == ReactionRoundOutcome.falseStart) {
      if (result!.falseStarter == player) {
        title = 'TOO EARLY!';
        caption = 'FALSE START';
      } else {
        title = '+1 POINT';
        caption = 'OPPONENT FALSE START';
      }
    } else if (result?.outcome == ReactionRoundOutcome.tie) {
      title = 'SO CLOSE!';
      value = _milliseconds(result?.reactionTimes[player]);
      caption = '${result?.difference?.inMilliseconds ?? 0} ms APART • REPLAY';
    } else if (result?.winner == player) {
      title = 'NICE REACTION!';
      value = _milliseconds(result?.reactionTimes[player]);
      caption = '+1 POINT';
    } else if (result?.outcome == ReactionRoundOutcome.point) {
      title = 'OPPONENT WAS FASTER';
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Column(
        key: ValueKey('${controller.phase}-${result?.outcome}-$player'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontFamily: 'Lilita One',
              fontSize: 22,
              letterSpacing: 1.3,
            ),
          ),
          if (value != null) ...[
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Lilita One',
                fontSize: 34,
              ),
            ),
          ],
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SignalCore extends StatelessWidget {
  const _SignalCore({required this.controller});

  final ReactionDuelController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.lastResult;
    final asset = switch ((controller.phase, result?.outcome)) {
      (ReactionPhase.signal, _) =>
        'assets/games/reaction_duel/reaction_signal_go.png',
      (ReactionPhase.resolving, ReactionRoundOutcome.tie) =>
        'assets/games/reaction_duel/reaction_tie_burst.png',
      (ReactionPhase.resolving, ReactionRoundOutcome.falseStart) =>
        result?.falseStarter == 0
            ? 'assets/games/reaction_duel/reaction_false_start_cool.png'
            : 'assets/games/reaction_duel/reaction_false_start_warm.png',
      (ReactionPhase.resolving, ReactionRoundOutcome.point) =>
        'assets/games/reaction_duel/reaction_tap_ripple.png',
      _ => 'assets/games/reaction_duel/reaction_signal_idle.png',
    };
    final label = switch (controller.phase) {
      ReactionPhase.preparing => 'GET READY',
      ReactionPhase.waiting => 'WAIT…',
      ReactionPhase.signal => 'TAP!',
      ReactionPhase.resolving => switch (result?.outcome) {
        ReactionRoundOutcome.tie => 'DRAW',
        ReactionRoundOutcome.falseStart => 'FALSE START',
        _ => '+1 POINT',
      },
    };

    Widget image = Image.asset(asset, fit: BoxFit.contain);
    if (result?.outcome == ReactionRoundOutcome.point) {
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(
          result?.winner == 0 ? _cool : _warm,
          BlendMode.modulate,
        ),
        child: image,
      );
    }

    return IgnorePointer(
      child: Semantics(
        liveRegion: controller.phase == ReactionPhase.signal,
        label: label,
        excludeSemantics: true,
        child: SizedBox(
          width: 190,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              TweenAnimationBuilder<double>(
                key: ValueKey(asset),
                tween: Tween(begin: .7, end: 1),
                curve: Curves.elasticOut,
                duration: const Duration(milliseconds: 500),
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: image,
              ),
              Positioned(
                bottom: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _navy.withValues(alpha: .88),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _gold.withValues(alpha: .8)),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _milliseconds(Duration? duration) =>
    duration == null ? null : '${duration.inMilliseconds} ms';
