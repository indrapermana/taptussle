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
  roundReveal,
  scoreWarm,
  scoreCool,
  impactSoft,
  impactHeavy,
  pieceMove,
  boardCapture,
  collect,
  cardFlip,
  cardDraw,
  cardPlace,
  cardShuffle,
  diceRoll,
  matchPair,
  liquidPour,
  metalSlide,
  snakeEat,
  snakeBoost,
  snakeCrash,
  tokenHome,
  levelUp,
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
  SoundEffect.roundReveal: 'audio/shared/round_reveal.wav',
  SoundEffect.scoreWarm: 'audio/shared/score_warm.wav',
  SoundEffect.scoreCool: 'audio/shared/score_cool.wav',
  SoundEffect.impactSoft: 'audio/shared/impact_soft.wav',
  SoundEffect.impactHeavy: 'audio/shared/impact_heavy.wav',
  SoundEffect.pieceMove: 'audio/shared/piece_move.wav',
  SoundEffect.boardCapture: 'audio/shared/board_capture.wav',
  SoundEffect.collect: 'audio/shared/collect.wav',
  SoundEffect.cardFlip: 'audio/shared/card_flip.wav',
  SoundEffect.cardDraw: 'audio/shared/card_draw.wav',
  SoundEffect.cardPlace: 'audio/shared/card_place.wav',
  SoundEffect.cardShuffle: 'audio/shared/card_shuffle.wav',
  SoundEffect.diceRoll: 'audio/shared/dice_roll.wav',
  SoundEffect.matchPair: 'audio/shared/match_pair.wav',
  SoundEffect.liquidPour: 'audio/shared/liquid_pour.wav',
  SoundEffect.metalSlide: 'audio/shared/metal_slide.wav',
  SoundEffect.snakeEat: 'audio/shared/snake_eat.wav',
  SoundEffect.snakeBoost: 'audio/shared/snake_boost.wav',
  SoundEffect.snakeCrash: 'audio/shared/snake_crash.wav',
  SoundEffect.tokenHome: 'audio/shared/token_home.wav',
  SoundEffect.levelUp: 'audio/shared/level_up.wav',
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
    _audioContextReady = _configureAudioContext();
  }

  final _players = List.generate(3, (_) => AudioPlayer());
  late final Future<void> _audioContextReady;
  final _lastStarted = <SoundEffect, DateTime>{};
  static const _duplicateCooldown = Duration(milliseconds: 35);
  var _nextPlayer = 0;
  double _volume = .7;

  Future<void> _configureAudioContext() async {
    final context = AudioContextConfig(
      route: AudioContextConfigRoute.system,
      respectSilence: true,
    ).build();
    await AudioPlayer.global.setAudioContext(context);
    for (final player in _players) {
      await player.setAudioContext(context);
    }
  }

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
      await _audioContextReady;
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
