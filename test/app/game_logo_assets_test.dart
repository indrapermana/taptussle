import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/app/game_logo_assets.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/features/home/game_artwork.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectedIds = {
    'paddle-duel',
    'reaction-duel',
    'air-hockey',
    'lane-dash',
    'tic-tac-toe',
    'memory-match',
    'rock-paper-scissors',
    'snakes-and-ladders',
    'sudoku',
    'checkers',
    'mancala',
    'slither-style-snakes',
    'water-sort-puzzle',
    'ludo',
    'nuts-and-bolts',
    'solitaire',
    'cangkulan',
    'chess',
  };

  test('all 18 stable game IDs resolve to bundled 1x and 2x logos', () async {
    expect(gameLogoAssets.keys.toSet(), expectedIds);
    expect(gameLogoAssets.values.toSet(), hasLength(expectedIds.length));

    for (final asset in gameLogoAssets.values) {
      expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(0));
      final separator = asset.lastIndexOf('/');
      final variant =
          '${asset.substring(0, separator)}/2.0x/${asset.substring(separator + 1)}';
      expect((await rootBundle.load(variant)).lengthInBytes, greaterThan(0));
    }
  });

  test('implemented catalog entries use their stable logo mapping', () {
    for (final game in gameCatalog) {
      expect(game.artworkAsset, gameLogoAssets[game.id]);
    }
  });

  testWidgets('missing artwork safely falls back to the game icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 220,
          height: 240,
          child: GameArtwork(
            gameId: 'missing',
            assetPath: 'assets/game_logos/catalog/missing.png',
            icon: Icons.extension_rounded,
            accent: TapTussleColors.electricBlue,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('game-artwork-fallback-missing')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.extension_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
