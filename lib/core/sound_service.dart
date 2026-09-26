import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import 'match_options.dart';
import 'match_session.dart';

enum SoundEffect {
  uiTap,
  uiConfirm,
  uiBack,
  uiInvalid,
  countdownTick,
  countdownGo,
  roundStart,
  scoreWarm,
  scoreCool,
  impactSoft,
  impactHeavy,
  pieceMove,
  collect,
  cardFlip,
  diceRoll,
  matchPair,
  puzzleComplete,
  resultWin,
  resultDraw,
  resultLose,
}

const soundEffectAssets = <SoundEffect, String>{
  SoundEffect.uiTap: 'audio/shared/ui_tap.wav',
  SoundEffect.uiConfirm: 'audio/shared/ui_confirm.wav',
  SoundEffect.uiBack: 'audio/shared/ui_back.wav',
  SoundEffect.uiInvalid: 'audio/shared/ui_invalid.wav',
  SoundEffect.countdownTick: 'audio/shared/countdown_tick.wav',
  SoundEffect.countdownGo: 'audio/shared/countdown_go.wav',
  SoundEffect.roundStart: 'audio/shared/round_start.wav',
  SoundEffect.scoreWarm: 'audio/shared/score_warm.wav',
  SoundEffect.scoreCool: 'audio/shared/score_cool.wav',
  SoundEffect.impactSoft: 'audio/shared/impact_soft.wav',
  SoundEffect.impactHeavy: 'audio/shared/impact_heavy.wav',
  SoundEffect.pieceMove: 'audio/shared/piece_move.wav',
  SoundEffect.collect: 'audio/shared/collect.wav',
  SoundEffect.cardFlip: 'audio/shared/card_flip.wav',
  SoundEffect.diceRoll: 'audio/shared/dice_roll.wav',
  SoundEffect.matchPair: 'audio/shared/match_pair.wav',
  SoundEffect.puzzleComplete: 'audio/shared/puzzle_complete.wav',
  SoundEffect.resultWin: 'audio/shared/result_win.wav',
  SoundEffect.resultDraw: 'audio/shared/result_draw.wav',
  SoundEffect.resultLose: 'audio/shared/result_lose.wav',
};

SoundEffect scoreEffectForParticipant(MatchOptions options, int player) =>
    switch (options.participants[player].color) {
      ParticipantColor.coral || ParticipantColor.gold => SoundEffect.scoreWarm,
      ParticipantColor.mint || ParticipantColor.violet => SoundEffect.scoreCool,
    };

SoundEffect resultEffectForMatch({
  required MatchOptions options,
  required MatchOutcome? outcome,
  required int? winner,
}) {
  if (outcome == MatchOutcome.draw) return SoundEffect.resultDraw;
  if (winner != null && options.mode != PlayMode.friend) {
    return options.participants[winner].isBot
        ? SoundEffect.resultLose
        : SoundEffect.resultWin;
  }
  return SoundEffect.resultWin;
}

abstract interface class SoundPlayer {
  void setVolume(double value);
  Future<void> play(SoundEffect effect);
}

/// A small, offline effects mixer using the bundled TapTussle sound pack.
class SoundService with WidgetsBindingObserver implements SoundPlayer {
  SoundService() {
    WidgetsBinding.instance.addObserver(this);
  }

  final _players = List.generate(3, (_) => AudioPlayer());
  final _lastStarted = <SoundEffect, DateTime>{};
  static const _duplicateCooldown = Duration(milliseconds: 35);
  var _nextPlayer = 0;
  double _volume = .7;

  @override
  void setVolume(double value) => _volume = value.clamp(0.0, 1.0).toDouble();

  @override
  Future<void> play(SoundEffect effect) async {
    if (_volume == 0) return;
    final now = DateTime.now();
    final lastStarted = _lastStarted[effect];
    if (lastStarted != null &&
        now.difference(lastStarted) < _duplicateCooldown) {
      return;
    }
    _lastStarted[effect] = now;
    final player = _players[_nextPlayer++ % _players.length];
    try {
      await player.stop();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(
        AssetSource(soundEffectAssets[effect]!),
        volume: _volume,
      );
    } catch (_) {
      // A missing platform audio backend must never interrupt a match.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      for (final player in _players) {
        player.stop();
      }
    }
  }

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    for (final player in _players) {
      await player.dispose();
    }
  }
}

/// Globally routes effects only after the application has configured audio.
/// Pure game-model tests intentionally have no active audio backend.
class SoundEffects {
  SoundEffects._();

  static SoundPlayer? _service;

  static void configure(SoundPlayer service) => _service = service;
  static void setVolume(double value) => _service?.setVolume(value);
  static Future<void> play(SoundEffect effect) =>
      _service?.play(effect) ?? Future.value();
}
