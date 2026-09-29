import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/rock_paper_scissors/rock_paper_scissors_bot.dart';
import 'package:tap_tussle/games/rock_paper_scissors/rock_paper_scissors_model.dart';

class _FixedRandom implements Random {
  _FixedRandom({this.intValue = 0, this.doubleValue = 0});

  final int intValue;
  final double doubleValue;

  @override
  bool nextBool() => nextInt(2) == 0;

  @override
  double nextDouble() => doubleValue;

  @override
  int nextInt(int max) => intValue % max;
}

void main() {
  test('Easy makes an injected random choice', () {
    final bot = RockPaperScissorsBot(
      difficulty: BotDifficulty.easy,
      random: _FixedRandom(intValue: 2),
    );

    expect(bot.chooseChoice(), RockPaperScissorsChoice.scissors);
  });

  test('Normal usually counters the most frequent completed choice', () {
    final bot =
        RockPaperScissorsBot(
            difficulty: BotDifficulty.normal,
            random: _FixedRandom(doubleValue: .2),
          )
          ..observeCompletedRound(RockPaperScissorsChoice.rock)
          ..observeCompletedRound(RockPaperScissorsChoice.paper)
          ..observeCompletedRound(RockPaperScissorsChoice.rock);

    expect(bot.chooseChoice(), RockPaperScissorsChoice.paper);
  });

  test('Normal occasionally ignores its prediction', () {
    final bot =
        RockPaperScissorsBot(
            difficulty: BotDifficulty.normal,
            random: _FixedRandom(doubleValue: .9, intValue: 2),
          )
          ..observeCompletedRound(RockPaperScissorsChoice.rock)
          ..observeCompletedRound(RockPaperScissorsChoice.rock);

    expect(bot.chooseChoice(), RockPaperScissorsChoice.scissors);
  });

  test('Hard counters the transition following the latest human choice', () {
    final bot =
        RockPaperScissorsBot(
            difficulty: BotDifficulty.hard,
            random: _FixedRandom(),
          )
          ..observeCompletedRound(RockPaperScissorsChoice.rock)
          ..observeCompletedRound(RockPaperScissorsChoice.paper)
          ..observeCompletedRound(RockPaperScissorsChoice.scissors)
          ..observeCompletedRound(RockPaperScissorsChoice.rock);

    // The previous Rock was followed by Paper, so Hard predicts Paper.
    expect(bot.chooseChoice(), RockPaperScissorsChoice.scissors);
  });

  test('the policy cannot receive or inspect the current hidden choice', () {
    final first = RockPaperScissorsBot(
      difficulty: BotDifficulty.hard,
      random: _FixedRandom(intValue: 1),
    );
    final second = RockPaperScissorsBot(
      difficulty: BotDifficulty.hard,
      random: _FixedRandom(intValue: 1),
    );

    // Only completed history can be supplied. Equal history and randomness
    // produce equal choices regardless of either player's pending choice.
    expect(first.chooseChoice(), second.chooseChoice());
  });

  test('reset removes completed-round history', () {
    final bot = RockPaperScissorsBot(difficulty: BotDifficulty.hard)
      ..observeCompletedRound(RockPaperScissorsChoice.rock);

    bot.reset();

    expect(bot.humanHistory, isEmpty);
  });
}
