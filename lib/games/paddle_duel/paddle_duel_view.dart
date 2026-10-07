import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/match_session.dart';
import '../../core/match_options.dart';
import 'paddle_duel_game.dart';
import 'paddle_duel_model.dart';
import 'paddle_duel_presentation.dart';

class PaddleDuelView extends StatefulWidget {
  const PaddleDuelView({
    required this.session,
    required this.options,
    this.resolution = ResolutionPreset.native,
    this.frameRate = FrameRatePreset.fps60,
    super.key,
  });
  final MatchSession session;
  final MatchOptions options;
  final ResolutionPreset resolution;
  final FrameRatePreset frameRate;
  @override
  State<PaddleDuelView> createState() => _PaddleDuelViewState();
}

class _PaddleDuelViewState extends State<PaddleDuelView> {
  late final PaddleDuelGame game;
  final Map<int, int> pointers = {};
  late List<int> _scores;
  Timer? _scoreNoticeTimer;
  int? _scoringParticipant;
  int round = 0;

  @override
  void initState() {
    super.initState();
    game = PaddleDuelGame(session: widget.session);
    _scores = List.of(widget.session.scores);
    widget.session.addListener(_syncSession);
    _syncSession();
  }

  void _syncSession() {
    final nextScores = widget.session.scores;
    if (nextScores.length >= 2 && _scores.length >= 2) {
      final scorer = nextScores[0] > _scores[0]
          ? 0
          : nextScores[1] > _scores[1]
          ? 1
          : null;
      if (scorer != null && widget.session.phase == MatchPhase.playing) {
        pointers.clear();
        _scoreNoticeTimer?.cancel();
        if (mounted) setState(() => _scoringParticipant = scorer);
        _scoreNoticeTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _scoringParticipant = null);
        });
      }
    }
    _scores = List.of(nextScores);
    if (round != widget.session.round) {
      round = widget.session.round;
      pointers.clear();
      _scoreNoticeTimer?.cancel();
      _scoringParticipant = null;
      game.resetMatch();
    }
    if (widget.session.phase != MatchPhase.playing) {
      pointers.clear();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_syncSession);
    _scoreNoticeTimer?.cancel();
    game.stopMatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final courtWidth = math.min(
        constraints.maxWidth,
        constraints.maxHeight * PaddleDuelModel.width / PaddleDuelModel.height,
      );
      final courtLeft = (constraints.maxWidth - courtWidth) / 2;

      void move(int pointer, Offset position) {
        final player = pointers[pointer];
        if (player == null ||
            widget.session.phase != MatchPhase.playing ||
            _scoringParticipant != null) {
          return;
        }
        game.model.movePaddle(
          player,
          (position.dx - courtLeft) / courtWidth * PaddleDuelModel.width,
        );
      }

      return Listener(
        key: const ValueKey('paddle-court'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (widget.session.phase != MatchPhase.playing ||
              _scoringParticipant != null) {
            return;
          }
          final player = event.localPosition.dy < constraints.maxHeight / 2
              ? 1
              : 0;
          if (widget.options.mode == PlayMode.bot && player == 1) return;
          // A finger stays assigned to its starting side until release.
          if (pointers.containsValue(player)) return;
          pointers[event.pointer] = player;
          move(event.pointer, event.localPosition);
        },
        onPointerMove: (event) => move(event.pointer, event.localPosition),
        onPointerUp: (event) => pointers.remove(event.pointer),
        onPointerCancel: (event) => pointers.remove(event.pointer),
        child: Center(
          child: AspectRatio(
            aspectRatio: PaddleDuelModel.width / PaddleDuelModel.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PaddleDuelPresentation(
                  game: game,
                  session: widget.session,
                  resolution: widget.resolution,
                  frameRate: widget.frameRate,
                ),
                if (_scoringParticipant case final scorer?)
                  _ScoreAnnouncement(
                    participantName: widget.options.playerLabel(scorer),
                    score: widget.session.scores[scorer],
                    color: scorer == 0
                        ? PaddleDuelGame.mint
                        : PaddleDuelGame.coral,
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ScoreAnnouncement extends StatelessWidget {
  const _ScoreAnnouncement({
    required this.participantName,
    required this.score,
    required this.color,
  });

  final String participantName;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('paddle-score-announcement'),
    container: true,
    liveRegion: true,
    label: '$participantName scored. Score $score.',
    excludeSemantics: true,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xCC061129),
          border: Border.symmetric(
            horizontal: BorderSide(color: color, width: 3),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: .62,
              child: Image.asset(
                'assets/games/paddle_duel/score_burst.png',
                fit: BoxFit.contain,
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    participantName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontFamily: 'Lilita One',
                      fontSize: 28,
                      letterSpacing: 1.2,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                  ),
                  const Text(
                    'SCORES!',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Lilita One',
                      fontSize: 36,
                      letterSpacing: 1.5,
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                    ),
                  ),
                  Text(
                    '$score',
                    style: TextStyle(
                      color: color,
                      fontFamily: 'Lilita One',
                      fontSize: 32,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
