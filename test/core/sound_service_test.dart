import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/core/sound_service.dart';

class _RecordingSoundPlayer implements SoundPlayer {
  double? volume;
  final played = <SoundEffect>[];

  @override
  Future<void> play(SoundEffect effect) async => played.add(effect);

  @override
  void setVolume(double value) => volume = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every shared sound effect resolves to one bundled asset', () async {
    expect(soundEffectAssets.keys.toSet(), SoundEffect.values.toSet());
    expect(
      soundEffectAssets.values.toSet(),
      hasLength(SoundEffect.values.length),
    );
    for (final asset in soundEffectAssets.values) {
      expect(
        (await rootBundle.load('assets/$asset')).lengthInBytes,
        greaterThan(0),
        reason: asset,
      );
    }
  });

  test('score and result cues reflect participant color and human outcome', () {
    final friend = MatchOptions.friend();
    final bot = MatchOptions.bot(difficulty: BotDifficulty.normal);

    expect(scoreEffectForParticipant(friend, 0), SoundEffect.scoreCool);
    expect(scoreEffectForParticipant(friend, 1), SoundEffect.scoreWarm);
    expect(
      resultEffectForMatch(
        options: bot,
        outcome: MatchOutcome.winner,
        winner: 0,
      ),
      SoundEffect.resultWin,
    );
    expect(
      resultEffectForMatch(
        options: bot,
        outcome: MatchOutcome.winner,
        winner: 1,
      ),
      SoundEffect.resultLose,
    );
    expect(
      resultEffectForMatch(
        options: friend,
        outcome: MatchOutcome.draw,
        winner: null,
      ),
      SoundEffect.resultDraw,
    );
  });

  test('shared facade forwards volume and requested playback', () async {
    final player = _RecordingSoundPlayer();
    SoundEffects.configure(player);

    SoundEffects.setVolume(.4);
    await SoundEffects.play(SoundEffect.uiConfirm);

    expect(player.volume, .4);
    expect(player.played, [SoundEffect.uiConfirm]);
  });
}
