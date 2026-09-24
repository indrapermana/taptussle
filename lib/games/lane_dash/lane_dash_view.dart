import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'lane_dash_game.dart';

class LaneDashView extends StatefulWidget {
  const LaneDashView({required this.session, required this.options, super.key});

  final MatchSession session;
  final MatchOptions options;

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
    game = LaneDashGame(widget.session);
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

  @override
  void dispose() {
    widget.session.removeListener(_sync);
    game.stopMatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      GameWidget(game: game),
      Listener(
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
          final delta = event.localPosition.dx - swipe.$2.dx;
          final threshold = (context.size!.width * .06).clamp(24.0, 48.0);
          if (delta.abs() < threshold) return;
          final direction = delta.isNegative ? -1 : 1;
          game.move(swipe.$1, swipe.$1 == 1 ? -direction : direction);
        },
        onPointerCancel: (event) => _swipes.remove(event.pointer),
        child: const SizedBox.expand(),
      ),
    ],
  );
}
