import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/paddle_duel/paddle_duel_model.dart';

void main() {
  late PaddleDuelModel model;
  setUp(() => model = PaddleDuelModel(winningScore: 5)..reset());

  test('serve countdown holds the ball before starting', () {
    for (var i = 0; i < 10; i++) {
      model.update(.1);
    }
    expect(model.ballY, 300);
    for (var i = 0; i < 10; i++) {
      model.update(.1);
    }
    expect(model.ballY, greaterThan(300));
  });

  test('paddles clamp to court bounds independently', () {
    model.movePaddle(0, -100);
    model.movePaddle(1, 1000);
    expect(model.paddles, [42, 318]);
  });

  test('side wall reflects the ball into the court', () {
    model
      ..serveRemaining = 0
      ..ballX = 8
      ..velocityX = -200;
    model.update(.03);
    expect(model.velocityX, greaterThan(0));
    expect(model.ballX, greaterThanOrEqualTo(7));
  });

  test('both paddle faces bounce without tunnelling at maximum speed', () {
    model
      ..serveRemaining = 0
      ..ballX = 180
      ..ballY = 540
      ..velocityX = 0
      ..velocityY = 500;
    model.update(.1);
    expect(model.velocityY, lessThan(0));
    expect(model.scores, [0, 0]);
    expect(model.paddleHitCount, 1);
    model
      ..ballY = 60
      ..velocityY = -500;
    model.update(.1);
    expect(model.velocityY, greaterThan(0));
    expect(model.scores, [0, 0]);
    expect(model.paddleHitCount, 2);
  });

  test('off-center paddle hit deflects toward the edge', () {
    model
      ..serveRemaining = 0
      ..ballX = 210
      ..ballY = 540
      ..velocityX = 0
      ..velocityY = 300;
    model.update(.04);
    expect(model.velocityX, greaterThan(0));
    expect(model.velocityY, lessThan(0));
  });

  test('a miss awards opponent exactly one point and resets serve', () {
    model
      ..serveRemaining = 0
      ..ballX = 20
      ..ballY = 604
      ..velocityX = 0
      ..velocityY = 400;
    model.update(.1);
    expect(model.scores, [0, 1]);
    expect(model.serveRemaining, 1.5);
    expect(model.ballY, 300);
    model.update(.1);
    expect(model.scores, [0, 1]);
  });

  test('win freezes simulation and reset starts a clean match', () {
    for (var i = 0; i < 5; i++) {
      model
        ..serveRemaining = 0
        ..ballX = 20
        ..ballY = -6
        ..velocityX = 0
        ..velocityY = -400;
      model.update(.02);
    }
    expect(model.winner, 0);
    expect(model.scores, [5, 0]);
    final y = model.ballY;
    model.update(.1);
    expect(model.ballY, y);
    model.reset();
    expect(model.scores, [0, 0]);
    expect(model.winner, isNull);
    expect(model.paddles, [180, 180]);
    expect(model.serveRemaining, 1.5);
  });

  test('long stalls are bounded and invalid deltas ignored', () {
    model
      ..serveRemaining = 0
      ..velocityX = 0
      ..velocityY = 100;
    model.update(30);
    expect(model.ballY, closeTo(310, .001));
    model.update(double.nan);
    model.update(-1);
    expect(model.ballY, closeTo(310, .001));
  });
}
