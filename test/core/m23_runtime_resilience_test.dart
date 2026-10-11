import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/cangkulan/cangkulan_progress_repository.dart';
import 'package:tap_tussle/games/ludo/ludo_progress_repository.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_levels.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_progress_repository.dart';
import 'package:tap_tussle/games/solitaire/solitaire_model.dart';
import 'package:tap_tussle/games/solitaire/solitaire_progress_repository.dart';
import 'package:tap_tussle/games/sudoku/sudoku_model.dart';
import 'package:tap_tussle/games/sudoku/sudoku_progress_repository.dart';
import 'package:tap_tussle/games/water_sort/water_sort_levels.dart';
import 'package:tap_tussle/games/water_sort/water_sort_progress_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wrong-type active saves are ignored across resumable games', () async {
    SharedPreferences.setMockInitialValues({
      'ludo.active.v2.h_h': 12,
      'cangkulan.active.v1.h_h': false,
      'solitaire.active.easy.v1': <String>['bad'],
      'solitaire.stats.easy.v1': 3,
      'sudoku.progress.easy': true,
      'sudoku.unlockedLevel.easy': 'five',
      'waterSort.active.easy.v1': 9,
      'waterSort.profile.easy.v1': <String, Object>{'bad': true},
      'nutsAndBolts.active.easy.v1': 9,
      'nutsAndBolts.profile.easy.v1': <String, Object>{'bad': true},
    });
    final preferences = await SharedPreferences.getInstance();
    final friend = MatchOptions.friend();

    expect(LudoProgressRepository(preferences).load(friend), isNull);
    expect(CangkulanProgressRepository(preferences).load(friend), isNull);

    final solitaire = SolitaireProgressRepository(preferences);
    expect(solitaire.loadActive(SolitaireDifficulty.easy), isNull);
    expect(solitaire.stats(SolitaireDifficulty.easy).wins, 0);

    final sudoku = SudokuProgressRepository(preferences);
    expect(sudoku.load(SudokuDifficulty.easy), isNull);
    expect(sudoku.unlockedLevel(SudokuDifficulty.easy), 1);

    final waterSort = WaterSortProgressRepository(preferences);
    expect(waterSort.loadActive(WaterSortDifficulty.easy), isNull);
    expect(waterSort.unlockedLevel(WaterSortDifficulty.easy), 1);

    final nutsAndBolts = NutsAndBoltsProgressRepository(preferences);
    expect(nutsAndBolts.loadActive(NutsAndBoltsDifficulty.easy), isNull);
    expect(nutsAndBolts.unlockedLevel(NutsAndBoltsDifficulty.easy), 1);
  });
}
