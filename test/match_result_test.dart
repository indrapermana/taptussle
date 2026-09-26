import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/core/mini_game.dart';
import 'package:tap_tussle/features/match/match_screen.dart';

MatchOptions _fourPlayers() => MatchOptions.custom(
  mode: PlayMode.friend,
  participants: const [
    MatchParticipant.human(
      displayName: 'One',
      color: ParticipantColor.mint,
      token: ParticipantToken.circle,
    ),
    MatchParticipant.human(
      displayName: 'Two',
      color: ParticipantColor.coral,
      token: ParticipantToken.diamond,
    ),
    MatchParticipant.human(
      displayName: 'Three',
      color: ParticipantColor.gold,
      token: ParticipantToken.triangle,
    ),
    MatchParticipant.human(
      displayName: 'Four',
      color: ParticipantColor.violet,
      token: ParticipantToken.star,
    ),
  ],
);

void main() {
  testWidgets(
    'shared results show a four-player winner and completion standings',
    (tester) async {
      MatchSession? session;
      final game = MiniGame(
        id: 'result-fixture',
        title: 'Result Fixture',
        subtitle: 'Test',
        instructions: 'Finish the fixture.',
        icon: Icons.flag_rounded,
        supportedModes: const {PlayMode.friend},
        supportedPlayerCounts: const {PlayerCount.four},
        build: (matchSession, _) {
          session = matchSession;
          return const SizedBox.expand();
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTapTussleTheme(),
          home: MatchScreen(
            game: game,
            options: _fourPlayers(),
            startImmediately: true,
          ),
        ),
      );
      session!.reportResult(
        outcome: MatchOutcome.winner,
        scores: [4, 7, 3, 9],
        winner: 3,
        standings: [3, 1, 0, 2],
      );
      await tester.pumpAndSettle();

      expect(find.text('Four wins!'), findsOneWidget);
      expect(
        find.text(
          '1. Four  •  2. Two  •  3. One  •  4. Three  •  Another round?',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Play again'));
      await tester.pump();
      session!.reportCompletion(
        scores: [12, 10, 8, 6],
        standings: [0, 1, 2, 3],
      );
      await tester.pumpAndSettle();

      expect(find.text('Complete!'), findsOneWidget);
      expect(
        find.text(
          '1. One  •  2. Two  •  3. Three  •  4. Four  •  Another round?',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
