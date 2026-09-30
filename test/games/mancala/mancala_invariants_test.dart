import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/mancala/mancala_bot.dart';
import 'package:tap_tussle/games/mancala/mancala_model.dart';

void main() {
  test(
    'seeded legal play conserves stones and always reaches a final result',
    () {
      for (var seed = 0; seed < 100; seed++) {
        final random = Random(seed);
        final model = MancalaModel(startingPlayer: seed.isEven ? 0 : 1);
        var turns = 0;

        while (!model.isFinished && turns < 500) {
          final player = model.currentPlayer;
          final legal = model.legalPitsFor(player);
          expect(legal, isNotEmpty, reason: 'seed $seed, turn $turns');
          final pit = legal[random.nextInt(legal.length)];
          final stones = model.stonesInPit(player, pit);

          expect(model.play(player, pit), MancalaMoveResult.accepted);
          final turn = model.lastTurn!;
          expect(turn.stonesSown, stones);
          expect(turn.sowingPath, hasLength(stones));
          expect(turn.sowingPath, isNot(contains(model.storeFor(1 - player))));
          expect(model.board, everyElement(greaterThanOrEqualTo(0)));
          expect(model.board.fold(0, (a, b) => a + b), 48);

          if (!model.isFinished) {
            expect(model.currentPlayer, turn.extraTurn ? player : 1 - player);
          }
          turns++;
        }

        expect(model.isFinished, isTrue, reason: 'seed $seed did not finish');
        expect(turns, lessThan(500));
        expect(model.board.take(6), everyElement(0));
        expect(model.board.skip(7).take(6), everyElement(0));
        expect(model.stonesInStore(0) + model.stonesInStore(1), 48);
        expect(model.outcome, isNotNull);
      }
    },
  );

  test(
    'Easy, Normal, and Hard complete legal matches without state corruption',
    () {
      for (final difficulty in BotDifficulty.values) {
        final random = Random(100 + difficulty.index);
        final bot = MancalaBot(difficulty: difficulty, random: random);
        final model = MancalaModel();
        var turns = 0;

        while (!model.isFinished && turns < 500) {
          final player = model.currentPlayer;
          final legal = model.legalPitsFor(player);
          final pit = player == bot.player
              ? bot.choosePit(model)
              : legal[random.nextInt(legal.length)];
          expect(pit, isNotNull);
          expect(legal, contains(pit));
          expect(model.play(player, pit!), MancalaMoveResult.accepted);
          expect(model.board.fold(0, (a, b) => a + b), 48);
          turns++;
        }

        expect(model.isFinished, isTrue, reason: '${difficulty.label} bot');
        expect(model.stonesInStore(0) + model.stonesInStore(1), 48);
        expect(bot.searchedNodes, lessThanOrEqualTo(bot.nodeBudget));
      }
    },
  );
}
