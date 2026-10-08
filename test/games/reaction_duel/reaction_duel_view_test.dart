import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/reaction_duel/reaction_duel_view.dart';

void main() {
  testWidgets(
    'friend mode makes each full half tappable and mirrors player two',
    (tester) async {
      final session = MatchSession(
        options: MatchOptions.friend(winningScore: 5),
      )..start();
      addTearDown(session.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReactionDuelView(session: session, options: session.options),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('reaction-zone-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('reaction-zone-1')), findsOneWidget);
      expect(find.text('GET READY'), findsNWidgets(3));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('reaction-zone-1')),
          matching: find.byType(RotatedBox),
        ),
        findsOneWidget,
      );

      await tester.tapAt(
        tester
                .getRect(find.byKey(const ValueKey('reaction-zone-0')))
                .bottomLeft +
            const Offset(30, -30),
      );
      await tester.pump();

      expect(session.scores, [0, 1]);
      expect(find.text('TOO EARLY!'), findsOneWidget);
      expect(find.text('+1 POINT'), findsOneWidget);
      expect(find.text('FALSE START'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bot zone ignores human input', (tester) async {
    final session = MatchSession(
      options: MatchOptions.bot(difficulty: BotDifficulty.easy),
    )..start();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReactionDuelView(session: session, options: session.options),
        ),
      ),
    );

    await tester.tapAt(
      tester.getRect(find.byKey(const ValueKey('reaction-zone-1'))).topLeft +
          const Offset(30, 30),
    );
    await tester.pump(const Duration(milliseconds: 650));

    expect(session.scores, [0, 0]);
    expect(find.text('BOT REACTION ZONE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'simultaneous pointers across both halves show an intentional tie',
    (tester) async {
      final session = MatchSession(
        options: MatchOptions.friend(winningScore: 5),
      )..start();
      addTearDown(session.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReactionDuelView(session: session, options: session.options),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 5));

      final top = tester.getCenter(
        find.byKey(const ValueKey('reaction-zone-1')),
      );
      final bottom = tester.getCenter(
        find.byKey(const ValueKey('reaction-zone-0')),
      );
      final first = await tester.startGesture(bottom, pointer: 1);
      final second = await tester.startGesture(top, pointer: 2);
      await tester.pump();

      expect(session.scores, [0, 0]);
      expect(find.text('SO CLOSE!'), findsNWidgets(2));
      expect(find.text('DRAW'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await first.up();
      await second.up();
    },
  );
}
