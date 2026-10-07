import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/chess/chess_bot.dart';
import 'package:tap_tussle/games/chess/chess_model.dart';

void main() {
  group('ChessBot', () {
    test('every difficulty returns a legal move without mutating state', () {
      final model = ChessModel().play(_move('e2', 'e4')).model;
      final key = model.positionKey;

      for (final difficulty in BotDifficulty.values) {
        for (var seed = 0; seed < 4; seed++) {
          final bot = ChessBot(difficulty: difficulty, random: Random(seed));
          expect(model.legalMoves, contains(bot.chooseMove(model)));
          expect(model.positionKey, key);
          expect(model.history.single.notation, 'e4');
        }
      }
    });

    test('profiles increase search strength and enforce node ceilings', () {
      final model = ChessModel().play(_move('e2', 'e4')).model;
      final easy = ChessBot(difficulty: BotDifficulty.easy, random: Random(1));
      final normal = ChessBot(
        difficulty: BotDifficulty.normal,
        random: Random(1),
        mistakeChance: 0,
      );
      final hard = ChessBot(difficulty: BotDifficulty.hard, random: Random(1));

      easy.chooseMove(model);
      normal.chooseMove(model);
      hard.chooseMove(model);

      expect(
        (easy.searchDepth, normal.searchDepth, hard.searchDepth),
        (0, 2, 3),
      );
      expect(easy.searchedNodes, 0);
      expect(normal.searchedNodes, inInclusiveRange(1, normal.nodeBudget));
      expect(hard.searchedNodes, inInclusiveRange(1, hard.nodeBudget));
      expect(normal.nodeBudget, lessThan(hard.nodeBudget));
      expect(normal.timeBudget, lessThan(hard.timeBudget));
    });

    test('Normal and Hard take a freely available queen', () {
      final model = ChessModel.fromState(
        board: {
          _sq('e1'): _white(ChessPieceType.king),
          _sq('a1'): _white(ChessPieceType.queen),
          _sq('e8'): _black(ChessPieceType.king),
          _sq('a8'): _black(ChessPieceType.rook),
        },
        sideToMove: ChessColor.black,
      );

      for (final difficulty in const [
        BotDifficulty.normal,
        BotDifficulty.hard,
      ]) {
        final bot = ChessBot(
          difficulty: difficulty,
          random: Random(2),
          mistakeChance: 0,
        );
        expect(bot.chooseMove(model), _move('a8', 'a1'));
      }
    });

    test('searched difficulties choose an immediate checkmate', () {
      var model = ChessModel();
      model = model.play(_move('f2', 'f3')).model;
      model = model.play(_move('e7', 'e5')).model;
      model = model.play(_move('g2', 'g4')).model;

      for (final difficulty in const [
        BotDifficulty.normal,
        BotDifficulty.hard,
      ]) {
        final bot = ChessBot(
          difficulty: difficulty,
          random: Random(3),
          mistakeChance: 0,
        );
        expect(bot.chooseMove(model), _move('d8', 'h4'));
      }
    });

    test('wrong turn and finished games do not produce moves', () {
      final bot = ChessBot(difficulty: BotDifficulty.hard);
      expect(bot.chooseMove(ChessModel()), isNull);
      final mate = ChessModel.fromState(
        board: {
          _sq('h8'): _black(ChessPieceType.king),
          _sq('g7'): _white(ChessPieceType.queen),
          _sq('g6'): _white(ChessPieceType.king),
        },
        sideToMove: ChessColor.black,
      );
      expect(bot.chooseMove(mate), isNull);
    });

    test('wall-clock budget still returns a legal fallback move', () {
      final model = ChessModel().play(_move('e2', 'e4')).model;
      final bot = ChessBot(
        difficulty: BotDifficulty.hard,
        random: Random(8),
        nodeBudget: 100000,
        timeBudget: const Duration(microseconds: 1),
      );

      expect(model.legalMoves, contains(bot.chooseMove(model)));
      expect(bot.searchedNodes, lessThan(bot.nodeBudget));
    });

    test('Hard opening search stays inside the host response guard', () {
      final model = ChessModel().play(_move('e2', 'e4')).model;
      final bot = ChessBot(difficulty: BotDifficulty.hard, random: Random(9));
      final stopwatch = Stopwatch()..start();

      final move = bot.chooseMove(model);
      stopwatch.stop();

      expect(model.legalMoves, contains(move));
      expect(bot.searchedNodes, lessThanOrEqualTo(bot.nodeBudget));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
    });
  });
}

ChessMove _move(String from, String to) =>
    ChessMove(from: _sq(from), to: _sq(to));
int _sq(String value) => ChessModel.parseSquare(value);
ChessPiece _white(ChessPieceType type) => ChessPiece(ChessColor.white, type);
ChessPiece _black(ChessPieceType type) => ChessPiece(ChessColor.black, type);
