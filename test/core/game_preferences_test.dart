import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/mini_game.dart';

MiniGame definition(String id) => MiniGame(
  id: id,
  title: id,
  subtitle: '',
  instructions: '',
  icon: Icons.games,
  build: (_, options) => const SizedBox(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'favourites partition catalog stably, ignore stale IDs and restore order',
    () {
      final games = ['a', 'b', 'c', 'd'].map(definition).toList();
      expect(favouritesFirst(games, {'c', 'b', 'removed'}).map((g) => g.id), [
        'b',
        'c',
        'a',
        'd',
      ]);
      expect(favouritesFirst(games, {'c'}).map((g) => g.id), [
        'c',
        'a',
        'b',
        'd',
      ]);
      expect(games.map((g) => g.id), ['a', 'b', 'c', 'd']);
    },
  );

  test(
    'favourites and independent per-game options survive storage reload',
    () async {
      SharedPreferences.setMockInitialValues({'winningScore': 11});
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);
      addTearDown(settings.dispose);
      await Future.wait([
        settings.setFavourite('a', true),
        settings.setFavourite('b', true),
      ]);
      await settings.saveGamePreferences(
        'a',
        const GamePreferences(
          mode: PlayMode.bot,
          difficulty: BotDifficulty.hard,
        ),
      );
      await settings.saveGamePreferences(
        'b',
        const GamePreferences(difficulty: BotDifficulty.easy),
      );
      await prefs.reload();
      final restored = AppSettings(prefs);
      addTearDown(restored.dispose);
      expect(restored.favouriteIds, {'a', 'b'});
      expect(restored.winningScore, 11);
      expect(restored.preferencesFor('a').mode, PlayMode.bot);
      expect(restored.preferencesFor('a').difficulty, BotDifficulty.hard);
      expect(restored.preferencesFor('b').mode, PlayMode.friend);
      expect(restored.preferencesFor('b').difficulty, BotDifficulty.easy);
      await restored.setFavourite('a', false);
      await prefs.reload();
      final again = AppSettings(prefs);
      addTearDown(again.dispose);
      expect(again.favouriteIds, {'b'});
    },
  );

  test('malformed and unknown persisted values fall back safely', () async {
    SharedPreferences.setMockInitialValues({
      'winningScore': 'bad',
      'favouriteGameIds': 'bad',
      'gameSetup.a': '{broken',
      'gameSetup.b': '{"mode":"network","difficulty":"extreme"}',
      'gameSetup.c': '[]',
    });
    final settings = AppSettings(await SharedPreferences.getInstance());
    addTearDown(settings.dispose);
    expect(settings.winningScore, 7);
    expect(settings.favouriteIds, isEmpty);
    for (final id in ['a', 'b', 'c', 'missing']) {
      expect(settings.preferencesFor(id).mode, PlayMode.friend);
      expect(settings.preferencesFor(id).difficulty, BotDifficulty.normal);
    }
  });

  test(
    'friend options exclude remembered bot difficulty and matches are frozen',
    () {
      final preferences = const GamePreferences(
        mode: PlayMode.bot,
        difficulty: BotDifficulty.hard,
      );
      final options = preferences.matchOptions(5);
      final friend = preferences
          .copyWith(mode: PlayMode.friend)
          .matchOptions(7);
      expect(options.botDifficulty, BotDifficulty.hard);
      expect(options.winningScore, 5);
      expect(friend.botDifficulty, isNull);
      expect(friend.playerLabel(1), 'Player 2');
      expect(options.playerLabel(0), 'You');
      expect(options.resultLabel(0), 'You win!');
      expect(options.resultLabel(1), 'Bot wins!');
    },
  );
}
