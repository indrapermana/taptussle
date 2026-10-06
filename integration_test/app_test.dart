import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/tap_tussle_app.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/game_record_repository.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/paddle_duel/paddle_duel_game.dart';
import 'package:tap_tussle/games/paddle_duel/paddle_duel_presentation.dart';
import 'package:tap_tussle/games/memory_match/memory_match_view.dart';
import 'package:tap_tussle/games/rock_paper_scissors/rock_paper_scissors_model.dart';
import 'package:tap_tussle/games/rock_paper_scissors/rock_paper_scissors_view.dart';
import 'package:tap_tussle/games/snakes_and_ladders/snakes_and_ladders_view.dart';
import 'package:tap_tussle/games/sudoku/sudoku_model.dart';
import 'package:tap_tussle/games/sudoku/sudoku_view.dart';
import 'package:tap_tussle/games/checkers/checkers_model.dart';
import 'package:tap_tussle/games/checkers/checkers_view.dart';
import 'package:tap_tussle/games/mancala/mancala_model.dart';
import 'package:tap_tussle/games/mancala/mancala_view.dart';
import 'package:tap_tussle/games/slither_snakes/slither_simulation.dart';
import 'package:tap_tussle/games/slither_snakes/slither_snakes_game.dart';
import 'package:tap_tussle/games/slither_snakes/slither_snakes_view.dart';
import 'package:tap_tussle/games/water_sort/water_sort_solver.dart';
import 'package:tap_tussle/games/water_sort/water_sort_view.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_solver.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_view.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<AppSettings> launchCleanApp(WidgetTester tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    final settings = AppSettings(preferences);
    await tester.pumpWidget(TapTussleApp(settings: settings));
    await tester.pumpAndSettle();
    return settings;
  }

  Future<void> setDifficulty(
    WidgetTester tester,
    BotDifficulty difficulty,
  ) async {
    final slider = tester.getRect(
      find.byKey(const ValueKey('bot-difficulty-slider')),
    );
    final fraction = .1 + (.8 * difficulty.index / 2);
    await tester.tapAt(
      Offset(slider.left + slider.width * fraction, slider.center.dy),
    );
    await tester.pumpAndSettle();
  }

  Future<void> forcePlayerOneWin(
    WidgetTester tester,
    PaddleDuelGame game,
  ) async {
    for (var point = 0; point < game.session.options.winningScore; point++) {
      game.model
        ..serveRemaining = 0
        ..ballY = -6
        ..velocityY = -400;
      game.update(.02);
    }
    await tester.pump();
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
    for (
      var attempt = 0;
      attempt < 50 && finder.evaluate().isEmpty;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finder, findsOneWidget);
  }

  testWidgets('friend match journey persists favourite and supports recovery', (
    tester,
  ) async {
    final settings = await launchCleanApp(tester);
    addTearDown(settings.dispose);

    await tester.tap(find.byKey(const ValueKey('game-card-paddle-duel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    expect(settings.isFavourite('paddle-duel'), isTrue);

    await tester.tap(find.byKey(const ValueKey('play-vs-friend')));
    await tester.pump(const Duration(milliseconds: 500));
    final game = tester
        .widget<PaddleDuelPresentation>(find.byType(PaddleDuelPresentation))
        .game;
    expect(game.session.phase, MatchPhase.playing);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Time out'), findsOneWidget);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('resume-match')));
    await tester.pump();

    await forcePlayerOneWin(tester, game);
    expect(find.text('Player 1 wins!'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();
    expect(game.model.scores, [0, 0]);

    await tester.tap(find.byTooltip('Pause match'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('change-options')));
    await tester.pumpAndSettle();
    expect(find.text('How to play'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(settings.isFavourite('paddle-duel'), isTrue);
  });

  testWidgets('each bot slider position starts the corresponding bot', (
    tester,
  ) async {
    final settings = await launchCleanApp(tester);
    addTearDown(settings.dispose);

    for (final difficulty in BotDifficulty.values) {
      await tester.tap(find.byKey(const ValueKey('game-card-paddle-duel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play-vs-bot')));
      await tester.pumpAndSettle();
      await setDifficulty(tester, difficulty);
      expect(find.text('Play ${difficulty.label}'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('start-bot-match')));
      await tester.pump(const Duration(milliseconds: 500));

      final game = tester
          .widget<PaddleDuelPresentation>(find.byType(PaddleDuelPresentation))
          .game;
      expect(game.bot!.difficulty, difficulty);

      await tester.tap(find.byTooltip('Pause match'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('change-options')));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    expect(settings.preferencesFor('paddle-duel').mode, PlayMode.bot);
    expect(
      settings.preferencesFor('paddle-duel').difficulty,
      BotDifficulty.hard,
    );
  });

  testWidgets('Memory Match solo journey saves a record and rematches', (
    tester,
  ) async {
    final settings = await launchCleanApp(tester);
    addTearDown(settings.dispose);

    await tester.tap(find.byKey(const ValueKey('player-filter-onePlayer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-card-memory-match')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-solo')));
    await tester.pumpAndSettle();
    await setDifficulty(tester, BotDifficulty.easy);
    await tester.tap(find.byKey(const ValueKey('start-bot-match')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    var board = tester.widget<MemoryMatchBoard>(find.byType(MemoryMatchBoard));
    for (var pair = 0; pair < board.controller.model.pairCount; pair++) {
      final indexes = <int>[];
      for (var index = 0; index < board.controller.model.cardCount; index++) {
        if (board.controller.model.deck[index] == pair) indexes.add(index);
      }
      await tester.tap(find.byKey(ValueKey('memory-card-${indexes[0]}')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('memory-card-${indexes[1]}')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Complete!'), findsOneWidget);
    expect(
      settings.recordRepository.recordsFor(
        const GameRecordKey(
          gameId: 'memory-match',
          recordType: 'solo',
          variant: 'easy',
        ),
      ),
      hasLength(1),
    );
    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();
    board = tester.widget<MemoryMatchBoard>(find.byType(MemoryMatchBoard));
    expect(board.controller.model.moveCount, 0);

    await tester.tap(find.byTooltip('Pause match'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('change-options')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-record-bests')), findsOneWidget);
    expect(find.text('Remove favourite'), findsOneWidget);
  });

  testWidgets('Slither solo journey pauses, records, and rematches', (
    tester,
  ) async {
    final settings = await launchCleanApp(tester);
    addTearDown(settings.dispose);

    await tester.tap(find.byKey(const ValueKey('player-filter-onePlayer')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('game-card-slither-style-snakes')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('play-solo')));
    await tester.tap(find.byKey(const ValueKey('play-solo')));
    await tester.pumpAndSettle();
    await setDifficulty(tester, BotDifficulty.hard);
    await tester.tap(find.byKey(const ValueKey('start-bot-match')));
    await pumpUntilFound(tester, find.byType(SlitherSnakesView));

    expect(find.byType(SlitherSnakesView), findsOneWidget);
    final gameWidget = tester.widget<GameWidget>(
      find.byWidgetPredicate(
        (widget) => widget is GameWidget && widget.game is SlitherSnakesGame,
      ),
    );
    final game = gameWidget.game as SlitherSnakesGame;
    expect(game.config.aiCount, 6);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Time out'), findsOneWidget);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.byKey(const ValueKey('resume-match')));
    await tester.pump();

    game.simulation.player
      ..age = 3
      ..segments[0] = SlitherPoint(
        game.config.arenaWidth - game.config.snakeRadius + 1,
        game.simulation.player.head.y,
      );
    game.update(SlitherSimulation.fixedStep);
    await pumpUntilFound(tester, find.text('Complete!'));

    expect(find.text('Complete!'), findsOneWidget);
    expect(find.byKey(const ValueKey('record-result-panel')), findsOneWidget);
    expect(
      settings.recordRepository.recordsFor(
        const GameRecordKey(
          gameId: 'slither-style-snakes',
          recordType: 'solo',
          variant: 'hard',
        ),
      ),
      hasLength(1),
    );
    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();
    expect(game.simulation.isGameOver, isFalse);
    expect(game.simulation.opponents, hasLength(6));
    expect(settings.isFavourite('slither-style-snakes'), isTrue);
  });

  testWidgets('Water Sort solo journey records and advances a level', (
    tester,
  ) async {
    final settings = await launchCleanApp(tester);
    addTearDown(settings.dispose);

    await tester.tap(find.byKey(const ValueKey('player-filter-onePlayer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-card-water-sort-puzzle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('play-solo')));
    await tester.tap(find.byKey(const ValueKey('play-solo')));
    await tester.pumpAndSettle();
    await setDifficulty(tester, BotDifficulty.easy);
    await tester.tap(find.byKey(const ValueKey('start-bot-match')));
    await pumpUntilFound(tester, find.byType(WaterSortBoard));

    final board = tester.widget<WaterSortBoard>(find.byType(WaterSortBoard));
    final solution = const WaterSortSolver().solve(board.controller.model)!;
    for (final move in solution.moves) {
      board.controller.tapTube(move.source);
      board.controller.tapTube(move.destination);
      await tester.pump(board.controller.animationDuration);
    }
    await tester.pumpAndSettle();

    expect(find.text('Complete!'), findsOneWidget);
    expect(
      settings.recordRepository.recordsFor(
        const GameRecordKey(
          gameId: 'water-sort-puzzle',
          recordType: 'solo',
          variant: 'easy',
        ),
      ),
      hasLength(1),
    );
    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();
    expect(board.controller.level.number, 2);
    expect(board.controller.model.moveCount, 0);
    expect(settings.isFavourite('water-sort-puzzle'), isTrue);
  });

  testWidgets('Nuts and Bolts solo journey records and advances a level', (
    tester,
  ) async {
    final settings = await launchCleanApp(tester);
    addTearDown(settings.dispose);

    await tester.tap(find.byKey(const ValueKey('player-filter-onePlayer')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-card-nuts-and-bolts')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('play-solo')));
    await tester.tap(find.byKey(const ValueKey('play-solo')));
    await tester.pumpAndSettle();
    await setDifficulty(tester, BotDifficulty.easy);
    await tester.tap(find.byKey(const ValueKey('start-bot-match')));
    await pumpUntilFound(tester, find.byType(NutsAndBoltsBoard));

    final board = tester.widget<NutsAndBoltsBoard>(
      find.byType(NutsAndBoltsBoard),
    );
    final solution = const NutsAndBoltsSolver().solve(board.controller.model)!;
    for (final move in solution.moves) {
      board.controller.tapBolt(move.source);
      board.controller.tapBolt(move.destination);
      await tester.pump(board.controller.animationDuration);
    }
    await tester.pumpAndSettle();

    expect(find.text('Complete!'), findsOneWidget);
    expect(
      settings.recordRepository.recordsFor(
        const GameRecordKey(
          gameId: 'nuts-and-bolts',
          recordType: 'solo',
          variant: 'easy',
        ),
      ),
      hasLength(1),
    );
    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();
    expect(board.controller.level.number, 2);
    expect(board.controller.model.moveCount, 0);
    expect(settings.isFavourite('nuts-and-bolts'), isTrue);
  });

  testWidgets('Rock Paper Scissors friend journey integrates and rematches', (
    tester,
  ) async {
    final settings = await launchCleanApp(tester);
    addTearDown(settings.dispose);
    await settings.setWinningScore(5);

    await tester.tap(find.byKey(const ValueKey('player-filter-twoPlayers')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('game-card-rock-paper-scissors')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    expect(settings.isFavourite('rock-paper-scissors'), isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('play-vs-friend')));
    await tester.pumpAndSettle();

    final board = tester.widget<RockPaperScissorsBoard>(
      find.byType(RockPaperScissorsBoard),
    );
    for (var round = 0; round < 5; round++) {
      if (board.controller.activePlayer == 0) {
        board.controller.selectChoice(RockPaperScissorsChoice.rock);
        board.controller.confirmHandoff();
        board.controller.selectChoice(RockPaperScissorsChoice.scissors);
      } else {
        board.controller.selectChoice(RockPaperScissorsChoice.scissors);
        board.controller.confirmHandoff();
        board.controller.selectChoice(RockPaperScissorsChoice.rock);
      }
      await tester.pump();
      if (round < 4) board.controller.startNextRound();
    }
    await tester.pumpAndSettle();

    expect(find.text('Player 1 wins!'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();
    expect(board.controller.model.scores, [0, 0]);
    expect(board.controller.model.roundCount, 0);

    await tester.tap(find.byTooltip('Pause match'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('change-options')));
    await tester.pumpAndSettle();
    expect(find.text('Remove favourite'), findsOneWidget);
  });

  testWidgets('Snakes and Ladders flexible setup and lifecycle journey', (
    tester,
  ) async {
    final settings = await launchCleanApp(tester);
    addTearDown(settings.dispose);

    await tester.tap(
      find.byKey(const ValueKey('player-filter-upToFourPlayers')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('game-card-snakes-and-ladders')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('configure-participants')),
    );
    await tester.tap(find.byKey(const ValueKey('configure-participants')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('participant-count-3')));
    await tester.pumpAndSettle();
    final secondKind = find.byKey(const ValueKey('participant-kind-1'));
    await tester.ensureVisible(secondKind);
    await tester.tap(
      find.descendant(of: secondKind, matching: find.text('Bot')),
    );
    await tester.pumpAndSettle();
    final start = find.byKey(const ValueKey('start-configured-match'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();

    var board = tester.widget<SnakesAndLaddersBoard>(
      find.byType(SnakesAndLaddersBoard),
    );
    expect(board.options.participants, hasLength(3));
    expect(board.options.participants[1].isBot, isTrue);
    await tester.tap(find.byKey(const ValueKey('snakes-roll')));
    await tester.pump(const Duration(seconds: 3));
    expect(board.controller.lastRoll, isNotNull);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Time out'), findsOneWidget);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('resume-match')));
    await tester.pump();

    await tester.tap(find.byTooltip('Pause match'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('change-options')));
    await tester.pumpAndSettle();
    expect(find.text('Remove favourite'), findsOneWidget);
    expect(settings.catalogPlayerFilter, CatalogPlayerFilter.upToFourPlayers);
  });

  testWidgets(
    'Sudoku solo persistence, lifecycle, result, and rematch journey',
    (tester) async {
      final settings = await launchCleanApp(tester);
      addTearDown(settings.dispose);

      await tester.tap(find.byKey(const ValueKey('player-filter-onePlayer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game-card-sudoku')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('play-solo')));
      await tester.tap(find.byKey(const ValueKey('play-solo')));
      await tester.pumpAndSettle();
      await setDifficulty(tester, BotDifficulty.easy);
      await tester.tap(find.byKey(const ValueKey('start-bot-match')));
      await tester.pumpAndSettle();

      final board = tester.widget<SudokuBoard>(find.byType(SudokuBoard));
      final puzzle = board.controller.model.puzzle;
      final notedCell = puzzle.givens.indexOf(0);
      board.controller.selectCell(notedCell);
      board.controller.toggleNotesMode();
      board.controller.enterNumber(2);

      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Time out'), findsOneWidget);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.byKey(const ValueKey('resume-match')));
      await tester.pump();
      expect(board.controller.model.notes[notedCell], {2});
      board.controller.toggleNotesMode();

      for (var cell = 0; cell < SudokuSolver.cellCount; cell++) {
        if (puzzle.givens[cell] != 0) continue;
        board.controller.selectCell(cell);
        board.controller.enterNumber(puzzle.solution[cell]);
      }
      await tester.pumpAndSettle();

      expect(find.text('Complete!'), findsOneWidget);
      expect(settings.isFavourite('sudoku'), isTrue);
      expect(
        settings.recordRepository.recordsFor(
          const GameRecordKey(
            gameId: 'sudoku',
            recordType: 'solo',
            variant: 'easy',
          ),
        ),
        hasLength(1),
      );
      await tester.tap(find.byKey(const ValueKey('play-again')));
      await tester.pump();
      expect(board.controller.model.puzzle.level, 2);
    },
  );

  testWidgets('Checkers friend lifecycle, result, and rematch journey', (
    tester,
  ) async {
    final settings = await launchCleanApp(tester);
    addTearDown(settings.dispose);

    await tester.tap(find.byKey(const ValueKey('player-filter-twoPlayers')));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('game-card-checkers'));
    await tester.scrollUntilVisible(
      card,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    expect(settings.isFavourite('checkers'), isTrue);
    await tester.ensureVisible(find.byKey(const ValueKey('play-vs-friend')));
    await tester.tap(find.byKey(const ValueKey('play-vs-friend')));
    await tester.pumpAndSettle();

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Time out'), findsOneWidget);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.byKey(const ValueKey('resume-match')));
    await tester.pump();

    var board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
    board.controller!.model = CheckersModel.fromBoard(
      board: {
        40: const CheckersPiece(player: 0),
        33: const CheckersPiece(player: 1),
      },
    );
    board.controller!.tapSquare(40);
    board.controller!.tapSquare(26);
    await tester.pumpAndSettle();
    expect(find.text('Player 1 wins!'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();
    board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
    expect(board.controller!.model.currentPlayer, 1);
    expect(board.controller!.model.pieceCount(0), 12);
    expect(board.controller!.model.pieceCount(1), 12);

    await tester.tap(find.byTooltip('Pause match'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('change-options')));
    await tester.pumpAndSettle();
    expect(find.text('Remove favourite'), findsOneWidget);
  });

  testWidgets('Mancala bot lifecycle, result, and rematch journey', (
    tester,
  ) async {
    final settings = await launchCleanApp(tester);
    addTearDown(settings.dispose);

    await tester.tap(find.byKey(const ValueKey('player-filter-twoPlayers')));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('game-card-mancala'));
    await tester.scrollUntilVisible(
      card,
      420,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    expect(settings.isFavourite('mancala'), isTrue);

    await tester.ensureVisible(find.byKey(const ValueKey('play-vs-bot')));
    await tester.tap(find.byKey(const ValueKey('play-vs-bot')));
    await tester.pumpAndSettle();
    await setDifficulty(tester, BotDifficulty.hard);
    await tester.tap(find.byKey(const ValueKey('start-bot-match')));
    await tester.pumpAndSettle();

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Time out'), findsOneWidget);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.byKey(const ValueKey('resume-match')));
    await tester.pump();

    var board = tester.widget<MancalaBoard>(find.byType(MancalaBoard));
    board.controller!.model = MancalaModel.fromBoard(
      board: const [0, 0, 0, 0, 0, 1, 30, 1, 0, 0, 0, 0, 0, 16],
    );
    board.controller!.tapPit(0, 5);
    await tester.pumpAndSettle();
    expect(find.text('You win!'), findsOneWidget);
    expect(find.textContaining('most stones'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();
    board = tester.widget<MancalaBoard>(find.byType(MancalaBoard));
    expect(board.controller!.model.currentPlayer, 1);
    expect(board.controller!.isBotThinking, isTrue);

    await tester.tap(find.byTooltip('Pause match'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('change-options')));
    await tester.pumpAndSettle();
    expect(find.text('Remove favourite'), findsOneWidget);
    expect(settings.preferencesFor('mancala').difficulty, BotDifficulty.hard);
  });
}
