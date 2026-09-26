import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/paddle_duel/paddle_duel_bot.dart';
import 'package:tap_tussle/games/paddle_duel/paddle_duel_game.dart';
import 'package:tap_tussle/games/paddle_duel/paddle_duel_model.dart';

void main() {
  for (final difficulty in BotDifficulty.values) {
    test(
      '${difficulty.label} only moves its paddle, with reaction and speed limits',
      () {
        final bot = PaddleDuelBot(difficulty, random: Random(42));
        final model = PaddleDuelModel(winningScore: 7)..reset();
        model
          ..serveRemaining = 0
          ..ballX = 300
          ..ballY = 300
          ..velocityX = 0
          ..velocityY = -300;
        bot.update(model, .01);
        expect(model.paddles[1], 180);
        for (var i = 0; i < 150; i++) {
          final previous = model.paddles[1];
          bot.update(model, 1 / 120);
          expect(
            (model.paddles[1] - previous).abs(),
            lessThanOrEqualTo(bot.maxSpeed / 120 + .0001),
          );
          expect(model.paddles[1], inInclusiveRange(42, 318));
        }
        expect(model.paddles[0], 180);
        expect(model.ballX, 300);
        expect(model.ballY, 300);
        expect(model.scores, [0, 0]);
        bot.reset();
        model.paddles[1] = 180;
        bot.update(model, .01);
        expect(model.paddles[1], 180);
      },
    );

    test(
      '${difficulty.label} can finish a match and stops on pause, result and disposal',
      () {
        final session = MatchSession(
          options: MatchOptions.bot(difficulty: difficulty, winningScore: 5),
        );
        addTearDown(session.dispose);
        final game = PaddleDuelGame(session: session, botRandom: Random(17));
        game.resetMatch();
        session.start();
        game.model.movePaddle(
          0,
          42,
        ); // Stationary player can lose a complete match.
        for (
          var i = 0;
          i < 120 * 180 && session.phase == MatchPhase.playing;
          i++
        ) {
          game.update(1 / 120);
        }
        expect(session.phase, MatchPhase.finished);
        final finished = List.of(game.model.paddles);
        game.update(.1);
        expect(game.model.paddles, finished);
        session.start();
        game.resetMatch();
        expect(game.model.scores, [0, 0]);
        session.pause();
        final before = [
          game.model.ballX,
          game.model.ballY,
          ...game.model.paddles,
        ];
        game.update(.1);
        expect([
          game.model.ballX,
          game.model.ballY,
          ...game.model.paddles,
        ], before);
        session.resume();
        game.stopMatch();
        game.update(.1);
        expect([
          game.model.ballX,
          game.model.ballY,
          ...game.model.paddles,
        ], before);
      },
    );
  }

  test('seeded inbound shots show increasing ability while Hard can miss', () {
    int saves(BotDifficulty difficulty) {
      final shots = Random(2026);
      var count = 0;
      for (var n = 0; n < 150; n++) {
        final model = PaddleDuelModel(winningScore: 7)..reset();
        model
          ..serveRemaining = 0
          ..ballX = 10 + shots.nextDouble() * 340
          ..ballY = n % 5 == 0 ? 100 : 300
          ..velocityX = (shots.nextDouble() * 2 - 1) * 200
          ..velocityY = -400;
        final bot = PaddleDuelBot(difficulty, random: Random(n));
        for (var frame = 0; frame < 150; frame++) {
          bot.update(model, 1 / 120);
          model.update(1 / 120);
          if (model.scores[0] > 0) break;
          if (model.velocityY > 0) {
            count++;
            break;
          }
        }
      }
      return count;
    }

    final easy = saves(BotDifficulty.easy);
    final normal = saves(BotDifficulty.normal);
    final hard = saves(BotDifficulty.hard);
    expect(normal, greaterThan(easy));
    expect(hard, greaterThan(normal));
    expect(hard, lessThan(150));
  });

  test(
    'bot decisions are reproducible with a seed and stable at 30/60 FPS',
    () {
      List<double> simulate(int fps) {
        final session = MatchSession(
          options: MatchOptions.bot(difficulty: BotDifficulty.normal),
        );
        final game = PaddleDuelGame(session: session, botRandom: Random(8));
        game.resetMatch();
        session.start();
        for (var i = 0; i < fps * 8; i++) {
          game.update(1 / fps);
        }
        final result = [
          game.model.ballX,
          game.model.ballY,
          ...game.model.paddles,
          ...game.model.scores.map((s) => s.toDouble()),
        ];
        game.stopMatch();
        session.dispose();
        return result;
      }

      final a = simulate(30);
      final b = simulate(60);
      for (var i = 0; i < a.length; i++) {
        expect(a[i], closeTo(b[i], .001));
      }
      expect(simulate(30), a);
    },
  );

  test('friend match has no bot', () {
    final session = MatchSession();
    addTearDown(session.dispose);
    expect(PaddleDuelGame(session: session).bot, isNull);
  });
}
