import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/rock_paper_scissors/rock_paper_scissors_model.dart';

void main() {
  group('RockPaperScissorsModel', () {
    const expectedOutcomes =
        <
          (RockPaperScissorsChoice, RockPaperScissorsChoice),
          RockPaperScissorsRoundOutcome
        >{
          (RockPaperScissorsChoice.rock, RockPaperScissorsChoice.rock):
              RockPaperScissorsRoundOutcome.draw,
          (RockPaperScissorsChoice.rock, RockPaperScissorsChoice.paper):
              RockPaperScissorsRoundOutcome.playerTwoWin,
          (RockPaperScissorsChoice.rock, RockPaperScissorsChoice.scissors):
              RockPaperScissorsRoundOutcome.playerOneWin,
          (RockPaperScissorsChoice.paper, RockPaperScissorsChoice.rock):
              RockPaperScissorsRoundOutcome.playerOneWin,
          (RockPaperScissorsChoice.paper, RockPaperScissorsChoice.paper):
              RockPaperScissorsRoundOutcome.draw,
          (RockPaperScissorsChoice.paper, RockPaperScissorsChoice.scissors):
              RockPaperScissorsRoundOutcome.playerTwoWin,
          (RockPaperScissorsChoice.scissors, RockPaperScissorsChoice.rock):
              RockPaperScissorsRoundOutcome.playerTwoWin,
          (RockPaperScissorsChoice.scissors, RockPaperScissorsChoice.paper):
              RockPaperScissorsRoundOutcome.playerOneWin,
          (RockPaperScissorsChoice.scissors, RockPaperScissorsChoice.scissors):
              RockPaperScissorsRoundOutcome.draw,
        };

    for (final entry in expectedOutcomes.entries) {
      test('${entry.key.$1.name} versus ${entry.key.$2.name}', () {
        expect(
          RockPaperScissorsModel.outcomeFor(entry.key.$1, entry.key.$2),
          entry.value,
        );
      });
    }

    test('starts with an immutable empty score and no completed rounds', () {
      final model = RockPaperScissorsModel(winningScore: 5);

      expect(model.winningScore, 5);
      expect(model.scores, [0, 0]);
      expect(() => model.scores[0] = 1, throwsUnsupportedError);
      expect(model.roundCount, 0);
      expect(model.lastRound, isNull);
      expect(model.winner, isNull);
      expect(model.isFinished, isFalse);
    });

    test('a draw records both choices without awarding a point', () {
      final model = RockPaperScissorsModel(winningScore: 3);

      final result = model.playRound(
        RockPaperScissorsChoice.paper,
        RockPaperScissorsChoice.paper,
      );

      expect(result, RockPaperScissorsPlayResult.roundDraw);
      expect(model.scores, [0, 0]);
      expect(model.roundCount, 1);
      expect(model.lastRound!.playerOneChoice, RockPaperScissorsChoice.paper);
      expect(model.lastRound!.playerTwoChoice, RockPaperScissorsChoice.paper);
      expect(model.lastRound!.outcome, RockPaperScissorsRoundOutcome.draw);
    });

    test('a non-final round awards exactly one point', () {
      final model = RockPaperScissorsModel(winningScore: 3);

      expect(
        model.playRound(
          RockPaperScissorsChoice.scissors,
          RockPaperScissorsChoice.paper,
        ),
        RockPaperScissorsPlayResult.playerOneScored,
      );
      expect(
        model.playRound(
          RockPaperScissorsChoice.rock,
          RockPaperScissorsChoice.paper,
        ),
        RockPaperScissorsPlayResult.playerTwoScored,
      );

      expect(model.scores, [1, 1]);
      expect(model.roundCount, 2);
      expect(model.winner, isNull);
    });

    test('the configured points-to-win value ends the match exactly', () {
      final model = RockPaperScissorsModel(winningScore: 2);

      expect(
        model.playRound(
          RockPaperScissorsChoice.rock,
          RockPaperScissorsChoice.scissors,
        ),
        RockPaperScissorsPlayResult.playerOneScored,
      );
      expect(model.isFinished, isFalse);
      expect(
        model.playRound(
          RockPaperScissorsChoice.paper,
          RockPaperScissorsChoice.rock,
        ),
        RockPaperScissorsPlayResult.playerOneWonMatch,
      );

      expect(model.scores, [2, 0]);
      expect(model.winner, 0);
      expect(model.isFinished, isTrue);
    });

    test('either player can win the configured match', () {
      final model = RockPaperScissorsModel(winningScore: 1);

      expect(
        model.playRound(
          RockPaperScissorsChoice.scissors,
          RockPaperScissorsChoice.rock,
        ),
        RockPaperScissorsPlayResult.playerTwoWonMatch,
      );
      expect(model.scores, [0, 1]);
      expect(model.winner, 1);
    });

    test('finished matches reject later rounds without changing state', () {
      final model = RockPaperScissorsModel(winningScore: 1);
      model.playRound(
        RockPaperScissorsChoice.rock,
        RockPaperScissorsChoice.scissors,
      );
      final completedRound = model.lastRound;

      expect(
        model.playRound(
          RockPaperScissorsChoice.paper,
          RockPaperScissorsChoice.rock,
        ),
        RockPaperScissorsPlayResult.matchFinished,
      );
      expect(model.scores, [1, 0]);
      expect(model.roundCount, 1);
      expect(model.lastRound, same(completedRound));
      expect(model.winner, 0);
    });

    test('reset and rematch clear all mutable match state', () {
      final model = RockPaperScissorsModel(winningScore: 1);
      model.playRound(
        RockPaperScissorsChoice.rock,
        RockPaperScissorsChoice.scissors,
      );

      model.reset();
      expect(model.scores, [0, 0]);
      expect(model.roundCount, 0);
      expect(model.lastRound, isNull);
      expect(model.winner, isNull);

      model.playRound(
        RockPaperScissorsChoice.paper,
        RockPaperScissorsChoice.rock,
      );
      model.startRematch();
      expect(model.scores, [0, 0]);
      expect(model.roundCount, 0);
      expect(model.lastRound, isNull);
      expect(model.isFinished, isFalse);
    });

    test('winning score must be positive', () {
      expect(
        () => RockPaperScissorsModel(winningScore: 0),
        throwsArgumentError,
      );
      expect(
        () => RockPaperScissorsModel(winningScore: -1),
        throwsArgumentError,
      );
    });
  });
}
