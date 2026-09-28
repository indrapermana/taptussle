import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/memory_match/memory_match_bot.dart';

class _FixedRandom implements Random {
  _FixedRandom({this.doubleValue = 0, this.intValue = 0});

  final double doubleValue;
  final int intValue;

  @override
  bool nextBool() => nextInt(2) == 0;

  @override
  double nextDouble() => doubleValue;

  @override
  int nextInt(int max) => intValue % max;
}

void main() {
  test('Hard completes pairs using only explicitly observed identities', () {
    final bot =
        MemoryMatchBot(difficulty: BotDifficulty.hard, random: _FixedRandom())
          ..observeCard(2, 7)
          ..observeCard(8, 7)
          ..observeCard(4, 3);

    final first = bot.chooseCard(legalIndexes: const [1, 2, 4, 8, 9]);
    expect(first, 2);
    final second = bot.chooseCard(
      legalIndexes: const [1, 4, 8, 9],
      revealedPairId: 7,
    );
    expect(second, 8);
  });

  test('unseen identities cannot influence a bot choice', () {
    final first = MemoryMatchBot(
      difficulty: BotDifficulty.hard,
      random: _FixedRandom(intValue: 2),
    );
    final second = MemoryMatchBot(
      difficulty: BotDifficulty.hard,
      random: _FixedRandom(intValue: 2),
    );

    // Neither bot receives card identities, so equal legal inputs produce the
    // same choice regardless of how a hidden deck might be arranged.
    expect(
      first.chooseCard(legalIndexes: const [3, 6, 9, 12]),
      second.chooseCard(legalIndexes: const [3, 6, 9, 12]),
    );
  });

  test('Easy and Normal keep bounded recent memory while Hard keeps all', () {
    final easy = MemoryMatchBot(difficulty: BotDifficulty.easy);
    final normal = MemoryMatchBot(difficulty: BotDifficulty.normal);
    final hard = MemoryMatchBot(difficulty: BotDifficulty.hard);

    for (var index = 0; index < 20; index++) {
      easy.observeCard(index, index ~/ 2);
      normal.observeCard(index, index ~/ 2);
      hard.observeCard(index, index ~/ 2);
    }

    expect(easy.rememberedCardCount, 4);
    expect(normal.rememberedCardCount, 10);
    expect(hard.rememberedCardCount, 20);
  });

  test('Easy can miss a known pair while Normal recalls the same pair', () {
    final easy =
        MemoryMatchBot(
            difficulty: BotDifficulty.easy,
            random: _FixedRandom(doubleValue: .7, intValue: 2),
          )
          ..observeCard(1, 5)
          ..observeCard(4, 5);
    final normal =
        MemoryMatchBot(
            difficulty: BotDifficulty.normal,
            random: _FixedRandom(doubleValue: .7, intValue: 2),
          )
          ..observeCard(1, 5)
          ..observeCard(4, 5);

    expect(easy.chooseCard(legalIndexes: const [1, 4, 8]), 8);
    expect(normal.chooseCard(legalIndexes: const [1, 4, 8]), 1);
  });

  test('every difficulty always chooses a legal card', () {
    for (final difficulty in BotDifficulty.values) {
      final bot =
          MemoryMatchBot(
              difficulty: difficulty,
              random: Random(difficulty.index),
            )
            ..observeCard(1, 2)
            ..observeCard(3, 2)
            ..observeCard(20, 9);
      for (var attempt = 0; attempt < 100; attempt++) {
        expect(
          bot.chooseCard(legalIndexes: const [3, 5, 7]),
          isIn(const [3, 5, 7]),
        );
      }
    }
  });

  test('reset forgets observations from the previous board', () {
    final bot = MemoryMatchBot(difficulty: BotDifficulty.hard)
      ..observeCard(1, 4)
      ..observeCard(5, 4);

    bot.reset();

    expect(bot.rememberedCardCount, 0);
  });
}
