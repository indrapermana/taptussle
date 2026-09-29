import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/checkers/checkers_bot.dart';
import 'package:tap_tussle/games/checkers/checkers_model.dart';

void main() {
  group('CheckersBot', () {
    test('every difficulty returns legal moves without mutating the model', () {
      final model = CheckersModel();
      model.play(0, const CheckersMove(from: 40, to: 33));
      final before = model.board;

      for (final difficulty in BotDifficulty.values) {
        for (var seed = 0; seed < 5; seed++) {
          final bot = CheckersBot(difficulty: difficulty, random: Random(seed));
          expect(model.legalMoves, contains(bot.chooseMove(model)));
          expect(model.board, before);
          expect(model.currentPlayer, 1);
        }
      }
    });

    test('profiles use increasing search depth with strict node bounds', () {
      final model = CheckersModel();
      model.play(0, const CheckersMove(from: 40, to: 33));
      final easy = CheckersBot(
        difficulty: BotDifficulty.easy,
        random: Random(1),
      );
      final normal = CheckersBot(
        difficulty: BotDifficulty.normal,
        random: Random(1),
        mistakeChance: 0,
      );
      final hard = CheckersBot(
        difficulty: BotDifficulty.hard,
        random: Random(1),
      );

      easy.chooseMove(model);
      normal.chooseMove(model);
      hard.chooseMove(model);

      expect(
        (easy.searchDepth, normal.searchDepth, hard.searchDepth),
        (0, 2, 4),
      );
      expect(easy.searchedNodes, 0);
      expect(normal.searchedNodes, inInclusiveRange(1, normal.nodeBudget));
      expect(hard.searchedNodes, inInclusiveRange(1, hard.nodeBudget));
      expect(normal.nodeBudget, lessThan(hard.nodeBudget));
    });

    test('search prefers a capture chain that wins more material', () {
      final model = CheckersModel.fromBoard(
        currentPlayer: 1,
        board: {
          17: const CheckersPiece(player: 1),
          21: const CheckersPiece(player: 1),
          26: const CheckersPiece(player: 0),
          30: const CheckersPiece(player: 0),
          44: const CheckersPiece(player: 0),
          56: const CheckersPiece(player: 0),
        },
      );

      for (final difficulty in const [
        BotDifficulty.normal,
        BotDifficulty.hard,
      ]) {
        final bot = CheckersBot(
          difficulty: difficulty,
          random: Random(2),
          mistakeChance: 0,
        );
        expect(
          bot.chooseMove(model),
          const CheckersMove(from: 17, to: 35, captured: 26),
        );
      }
    });

    test(
      'forced continuation is always legal and terminal states return null',
      () {
        final model = CheckersModel.fromBoard(
          currentPlayer: 1,
          board: {
            17: const CheckersPiece(player: 1),
            26: const CheckersPiece(player: 0),
            44: const CheckersPiece(player: 0),
            56: const CheckersPiece(player: 0),
          },
        );
        model.play(1, const CheckersMove(from: 17, to: 35));
        final bot = CheckersBot(difficulty: BotDifficulty.hard);

        expect(
          bot.chooseMove(model),
          const CheckersMove(from: 35, to: 53, captured: 44),
        );

        final finished = CheckersModel.fromBoard(
          currentPlayer: 1,
          board: {1: const CheckersPiece(player: 0)},
        );
        expect(finished.isFinished, isTrue);
        expect(bot.chooseMove(finished), isNull);
      },
    );
  });
}
