import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/tic_tac_toe/tic_tac_toe_bot.dart';
import 'package:tap_tussle/games/tic_tac_toe/tic_tac_toe_model.dart';

void main() {
  group('TicTacToeBot', () {
    test('returns null outside its turn or after the match', () {
      final model = TicTacToeModel();
      final bot = TicTacToeBot(
        difficulty: BotDifficulty.easy,
        random: Random(1),
      );

      expect(bot.chooseMove(model), isNull);
      for (final move in const [(0, 0), (1, 3), (0, 1), (1, 4), (0, 2)]) {
        expect(model.play(move.$1, move.$2), TicTacToeMoveResult.accepted);
      }
      expect(bot.chooseMove(model), isNull);
    });

    test('Easy always chooses a legal empty cell', () {
      final model = TicTacToeModel();
      expect(model.play(0, 4), TicTacToeMoveResult.accepted);

      for (var seed = 0; seed < 50; seed++) {
        final move = TicTacToeBot(
          difficulty: BotDifficulty.easy,
          random: Random(seed),
        ).chooseMove(model);
        expect(model.availableCells, contains(move));
      }
    });

    test('Normal takes an immediate win when it does not make a mistake', () {
      final model = _modelAfter(const [(0, 0), (1, 3), (0, 1), (1, 4), (0, 8)]);
      final bot = TicTacToeBot(
        difficulty: BotDifficulty.normal,
        normalMistakeChance: 0,
      );

      expect(bot.chooseMove(model), 5);
    });

    test('Normal blocks an immediate loss when it does not make a mistake', () {
      final model = _modelAfter(const [(0, 0), (1, 4), (0, 1)]);
      final bot = TicTacToeBot(
        difficulty: BotDifficulty.normal,
        normalMistakeChance: 0,
      );

      expect(bot.chooseMove(model), 2);
    });

    test('Normal occasionally permits a weaker legal choice', () {
      final model = _modelAfter(const [(0, 0), (1, 4), (0, 1)]);
      final choices = <int?>{
        for (var seed = 0; seed < 30; seed++)
          TicTacToeBot(
            difficulty: BotDifficulty.normal,
            normalMistakeChance: 1,
            random: Random(seed),
          ).chooseMove(model),
      };

      expect(choices, contains(2));
      expect(choices.any((cell) => cell != 2), isTrue);
      expect(choices.every(model.availableCells.contains), isTrue);
    });

    test('Hard never loses when moving second', () {
      final terminalGames = _exploreEveryHumanReply(startingPlayer: 0);
      expect(terminalGames, greaterThan(0));
    });

    test('Hard never loses when starting a rematch', () {
      final terminalGames = _exploreEveryHumanReply(startingPlayer: 1);
      expect(terminalGames, greaterThan(0));
    });

    test('choosing a move never mutates the model', () {
      final model = _modelAfter(const [(0, 0)]);
      final before = model.board;
      final bot = TicTacToeBot(difficulty: BotDifficulty.hard);

      expect(bot.chooseMove(model), isNotNull);
      expect(model.board, before);
      expect(model.moveCount, 1);
    });
  });
}

TicTacToeModel _modelAfter(List<(int, int)> moves, {int startingPlayer = 0}) {
  final model = TicTacToeModel(startingPlayer: startingPlayer);
  for (final move in moves) {
    expect(model.play(move.$1, move.$2), TicTacToeMoveResult.accepted);
  }
  return model;
}

int _exploreEveryHumanReply({required int startingPlayer}) {
  const botPlayer = 1;
  var terminalGames = 0;

  void explore(List<(int, int)> history) {
    final model = _modelAfter(history, startingPlayer: startingPlayer);
    if (model.isFinished) {
      expect(model.winner, isNot(1 - botPlayer));
      terminalGames++;
      return;
    }
    if (model.currentPlayer == botPlayer) {
      final move = TicTacToeBot(
        difficulty: BotDifficulty.hard,
        player: botPlayer,
      ).chooseMove(model);
      expect(model.availableCells, contains(move));
      explore([...history, (botPlayer, move!)]);
      return;
    }
    for (final move in model.availableCells) {
      explore([...history, (1 - botPlayer, move)]);
    }
  }

  explore(const []);
  return terminalGames;
}
