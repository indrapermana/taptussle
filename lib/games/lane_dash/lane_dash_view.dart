import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'lane_dash_game.dart';

class LaneDashView extends StatefulWidget {
  const LaneDashView({
    required this.session,
    required this.options,
    this.gameOverride,
    super.key,
  });

  final MatchSession session;
  final MatchOptions options;
  @visibleForTesting
  final LaneDashGame? gameOverride;

  @override
  State<LaneDashView> createState() => _LaneDashViewState();
}

class _LaneDashViewState extends State<LaneDashView> {
  late final LaneDashGame game;
  final Map<int, (int, Offset)> _swipes = {};
  int _round = -1;

  @override
  void initState() {
    super.initState();
    game = widget.gameOverride ?? LaneDashGame(widget.session);
    widget.session.addListener(_sync);
    _sync();
  }

  void _sync() {
    if (_round != widget.session.round) {
      _round = widget.session.round;
      _swipes.clear();
      game.resetMatch();
    } else if (widget.session.phase != MatchPhase.playing) {
      _swipes.clear();
    }
  }

  String _laneName(int player) => switch (game.model.lanes[player]) {
    0 => 'Left lane',
    1 => 'Middle lane',
    _ => 'Right lane',
  };

  void _moveFromSemantics(int player, int direction) {
    if (widget.session.phase != MatchPhase.playing ||
        (player == 1 && widget.options.mode == PlayMode.bot)) {
      return;
    }
    game.move(player, direction);
    setState(() {});
  }

  void _moveToLane(int player, double localX, double width) {
    final targetLane = (localX / (width / 3)).floor().clamp(0, 2);
    final direction = targetLane - game.model.lanes[player];
    if (direction == 0) return;
    game.move(player, direction);
    setState(() {});
  }

  @override
  void dispose() {
    widget.session.removeListener(_sync);
    game.stopMatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label:
        'Lane Dash. Swipe horizontally in your half to move between three lanes.',
    child: Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(child: GameWidget(game: game)),
        Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            widthFactor: 1,
            heightFactor: .5,
            child: Semantics(
              key: const ValueKey('lane-dash-player-zone-1'),
              container: true,
              label: widget.options.mode == PlayMode.bot
                  ? '${widget.options.playerLabel(1)} track'
                  : '${widget.options.playerLabel(1)} track. ${_laneName(1)}',
              hint: widget.options.mode == PlayMode.bot
                  ? 'The bot controls this car'
                  : 'Swipe left or right, tap a lane, or use adjust actions',
              onIncrease: widget.options.mode == PlayMode.bot
                  ? null
                  : () => _moveFromSemantics(1, 1),
              onDecrease: widget.options.mode == PlayMode.bot
                  ? null
                  : () => _moveFromSemantics(1, -1),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            widthFactor: 1,
            heightFactor: .5,
            child: Semantics(
              key: const ValueKey('lane-dash-player-zone-0'),
              container: true,
              label: '${widget.options.playerLabel(0)} track. ${_laneName(0)}',
              hint: 'Swipe left or right, tap a lane, or use adjust actions',
              onIncrease: () => _moveFromSemantics(0, 1),
              onDecrease: () => _moveFromSemantics(0, -1),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        ValueListenableBuilder<String>(
          valueListenable: game.accessibilityAnnouncement,
          builder: (context, announcement, _) => Align(
            alignment: Alignment.center,
            child: Semantics(
              key: const ValueKey('lane-dash-status'),
              container: true,
              liveRegion: true,
              label: announcement,
              child: const SizedBox(width: 1, height: 1),
            ),
          ),
        ),
        Listener(
          key: const ValueKey('lane-dash-track'),
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (widget.session.phase != MatchPhase.playing) return;
            final player = event.localPosition.dy < context.size!.height / 2
                ? 1
                : 0;
            if (player == 1 && widget.options.mode == PlayMode.bot) return;
            _swipes[event.pointer] = (player, event.localPosition);
          },
          onPointerUp: (event) {
            final swipe = _swipes.remove(event.pointer);
            if (swipe == null || widget.session.phase != MatchPhase.playing) {
              return;
            }
            final delta = event.localPosition - swipe.$2;
            final threshold = (context.size!.width * .06).clamp(24.0, 48.0);
            if (delta.distance < threshold) {
              _moveToLane(
                swipe.$1,
                event.localPosition.dx,
                context.size!.width,
              );
              return;
            }
            if (delta.dx.abs() <= delta.dy.abs()) {
              return;
            }
            game.move(swipe.$1, delta.dx.isNegative ? -1 : 1);
            setState(() {});
          },
          onPointerCancel: (event) => _swipes.remove(event.pointer),
          child: const SizedBox.expand(),
        ),
      ],
    ),
  );
}
