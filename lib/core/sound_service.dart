import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

enum SoundEffect { click, paddleHit, score, result }

/// A small, offline effects mixer using original bundled WAV tones.
class SoundService with WidgetsBindingObserver {
  SoundService() {
    WidgetsBinding.instance.addObserver(this);
  }

  final _players = List.generate(3, (_) => AudioPlayer());
  static const _sources = {
    SoundEffect.click: 'sounds/click.wav',
    SoundEffect.paddleHit: 'sounds/paddle_hit.wav',
    SoundEffect.score: 'sounds/score.wav',
    SoundEffect.result: 'sounds/result.wav',
  };
  var _nextPlayer = 0;
  double _volume = .7;

  void setVolume(double value) => _volume = value.clamp(0.0, 1.0).toDouble();

  Future<void> play(SoundEffect effect) async {
    if (_volume == 0) return;
    final player = _players[_nextPlayer++ % _players.length];
    try {
      await player.stop();
      await player.setReleaseMode(ReleaseMode.stop);
      await player.play(AssetSource(_sources[effect]!), volume: _volume);
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
}

/// Globally routes effects only after the application has configured audio.
/// Pure game-model tests intentionally have no active audio backend.
class SoundEffects {
  SoundEffects._();

  static SoundService? _service;

  static void configure(SoundService service) => _service = service;
  static void setVolume(double value) => _service?.setVolume(value);
  static Future<void> play(SoundEffect effect) =>
      _service?.play(effect) ?? Future.value();
}
