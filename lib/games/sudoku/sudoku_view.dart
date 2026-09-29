import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/haptic_service.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'sudoku_controller.dart';
import 'sudoku_model.dart';
import 'sudoku_progress_repository.dart';

class SudokuView extends StatefulWidget {
  const SudokuView({
    required this.session,
    required this.options,
    this.repository,
    super.key,
  });

  final MatchSession session;
  final MatchOptions options;
  final SudokuProgressRepository? repository;

  @override
  State<SudokuView> createState() => _SudokuViewState();
}

class _SudokuViewState extends State<SudokuView> {
  SudokuController? controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository =
        widget.repository ??
        SudokuProgressRepository(await SharedPreferences.getInstance());
    if (!mounted) return;
    final difficulty = SudokuDifficulty.values[widget.options.difficulty.index];
    final saved = repository.load(difficulty);
    final level = saved?.level ?? repository.unlockedLevel(difficulty);
    setState(() {
      controller = SudokuController(
        session: widget.session,
        puzzle: SudokuCatalog.puzzle(difficulty, level),
        repository: repository,
        restoredProgress: saved,
      );
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loadedController = controller;
    if (loadedController == null) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('sudoku-loading')),
      );
    }
    return SudokuBoard(controller: loadedController);
  }
}

class SudokuBoard extends StatelessWidget {
  const SudokuBoard({required this.controller, super.key});

  final SudokuController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      if (!controller.isBoardVisible) {
        return const Center(
          child: Text(
            'PUZZLE PAUSED',
            key: ValueKey('sudoku-paused'),
            style: TextStyle(
              fontFamily: 'Lilita One',
              fontSize: 24,
              color: TapTussleColors.mutedText,
              letterSpacing: 1,
            ),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        child: Column(
          children: [
            _StatusBar(controller: controller),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: _Grid(controller: controller),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _NumberPad(controller: controller),
            const SizedBox(height: 6),
            _ActionBar(controller: controller),
          ],
        ),
      );
    },
  );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller});

  final SudokuController controller;

  @override
  Widget build(BuildContext context) {
    final puzzle = controller.model.puzzle;
    final elapsed = controller.elapsed;
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Row(
      children: [
        Expanded(
          child: Text(
            '${puzzle.difficulty.name.toUpperCase()}  •  LEVEL ${puzzle.level}',
            style: const TextStyle(
              fontFamily: 'Lilita One',
              color: TapTussleColors.electricBlue,
              fontSize: 15,
              letterSpacing: .5,
            ),
          ),
        ),
        Text(
          '$minutes:$seconds',
          key: const ValueKey('sudoku-timer'),
          semanticsLabel: 'Elapsed time $minutes minutes $seconds seconds',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        Text(
          '${controller.model.mistakes} MISTAKES',
          key: const ValueKey('sudoku-mistakes'),
          style: const TextStyle(color: TapTussleColors.rivalRed, fontSize: 12),
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.controller});

  final SudokuController controller;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('sudoku-board'),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F2E8),
      border: Border.all(color: TapTussleColors.electricBlue, width: 2.5),
      boxShadow: [
        BoxShadow(
          color: TapTussleColors.electricBlue.withValues(alpha: .2),
          blurRadius: 14,
        ),
      ],
    ),
    child: GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 9,
      ),
      itemCount: SudokuSolver.cellCount,
      itemBuilder: (context, cell) => _Cell(controller: controller, cell: cell),
    ),
  );
}

class _Cell extends StatelessWidget {
  const _Cell({required this.controller, required this.cell});

  final SudokuController controller;
  final int cell;

  @override
  Widget build(BuildContext context) {
    final model = controller.model;
    final value = model.values[cell];
    final selected = controller.selectedCell == cell;
    final related = _isRelated(controller.selectedCell, cell);
    final sameValue =
        value != 0 &&
        controller.selectedCell != null &&
        model.values[controller.selectedCell!] == value;
    final incorrect = model.incorrectCells.contains(cell);
    final row = cell ~/ 9;
    final column = cell % 9;
    final background = incorrect
        ? TapTussleColors.rivalRed.withValues(alpha: .25)
        : selected
        ? TapTussleColors.gold.withValues(alpha: .38)
        : sameValue
        ? TapTussleColors.electricBlue.withValues(alpha: .26)
        : related
        ? TapTussleColors.electricBlue.withValues(alpha: .11)
        : Colors.transparent;
    final label = value == 0
        ? model.notes[cell].isEmpty
              ? 'Row ${row + 1}, column ${column + 1}, empty'
              : 'Row ${row + 1}, column ${column + 1}, notes ${model.notes[cell].join(', ')}'
        : 'Row ${row + 1}, column ${column + 1}, $value${incorrect ? ', incorrect' : ''}';

    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey('sudoku-cell-$cell'),
          onTap: () {
            controller.selectCell(cell);
            SoundEffects.play(SoundEffect.uiTap);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              border: Border(
                right: BorderSide(
                  color: column == 2 || column == 5
                      ? const Color(0xFF294D73)
                      : const Color(0x55294D73),
                  width: column == 2 || column == 5 ? 2 : .6,
                ),
                bottom: BorderSide(
                  color: row == 2 || row == 5
                      ? const Color(0xFF294D73)
                      : const Color(0x55294D73),
                  width: row == 2 || row == 5 ? 2 : .6,
                ),
              ),
            ),
            child: value == 0
                ? _Notes(values: model.notes[cell])
                : Center(
                    child: FittedBox(
                      child: Text(
                        '$value',
                        style: TextStyle(
                          color: incorrect
                              ? TapTussleColors.rivalRed
                              : model.isGiven(cell)
                              ? const Color(0xFF10284A)
                              : const Color(0xFF087AA5),
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  bool _isRelated(int? selected, int candidate) {
    if (selected == null) return false;
    final selectedRow = selected ~/ 9;
    final selectedColumn = selected % 9;
    final row = candidate ~/ 9;
    final column = candidate % 9;
    return row == selectedRow ||
        column == selectedColumn ||
        (row ~/ 3 == selectedRow ~/ 3 && column ~/ 3 == selectedColumn ~/ 3);
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.values});

  final Set<int> values;

  @override
  Widget build(BuildContext context) => GridView.count(
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 3,
    children: [
      for (var value = 1; value <= 9; value++)
        Center(
          child: Text(
            values.contains(value) ? '$value' : '',
            style: const TextStyle(
              color: Color(0xFF506987),
              fontSize: 8,
              height: 1,
            ),
          ),
        ),
    ],
  );
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({required this.controller});

  final SudokuController controller;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 46,
    child: Row(
      children: [
        for (var value = 1; value <= 9; value++) ...[
          if (value > 1) const SizedBox(width: 3),
          Expanded(
            child: FilledButton(
              key: ValueKey('sudoku-number-$value'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(30, 42),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              onPressed: controller.selectedCell == null
                  ? null
                  : () {
                      final wasNotesMode = controller.notesMode;
                      final result = controller.enterNumber(value);
                      if (wasNotesMode) {
                        SoundEffects.play(SoundEffect.uiTap);
                        HapticEffects.preview();
                      } else if (result == SudokuEntryResult.mistake) {
                        SoundEffects.play(SoundEffect.uiInvalid);
                        HapticEffects.paddleHit();
                      } else if (result == SudokuEntryResult.accepted) {
                        SoundEffects.play(SoundEffect.pieceMove);
                        HapticEffects.preview();
                      }
                    },
              child: Text('$value'),
            ),
          ),
        ],
      ],
    ),
  );
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.controller});

  final SudokuController controller;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey('sudoku-notes'),
          onPressed: () {
            controller.toggleNotesMode();
            SoundEffects.play(SoundEffect.uiTap);
          },
          style: controller.notesMode
              ? OutlinedButton.styleFrom(
                  backgroundColor: TapTussleColors.gold.withValues(alpha: .2),
                  side: const BorderSide(color: TapTussleColors.gold),
                )
              : null,
          icon: Icon(
            controller.notesMode ? Icons.edit_note_rounded : Icons.edit_rounded,
          ),
          label: Text(controller.notesMode ? 'NOTES ON' : 'NOTES'),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey('sudoku-erase'),
          onPressed: controller.selectedCell == null
              ? null
              : () {
                  if (controller.eraseSelected()) {
                    SoundEffects.play(SoundEffect.uiBack);
                    HapticEffects.preview();
                  }
                },
          icon: const Icon(Icons.backspace_outlined),
          label: const Text('ERASE'),
        ),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey('sudoku-hint'),
          onPressed: controller.model.hintsUsed >= SudokuModel.maximumHints
              ? null
              : () {
                  if (controller.revealHint() == SudokuHintResult.revealed) {
                    SoundEffects.play(SoundEffect.collect);
                    HapticEffects.paddleHit();
                  }
                },
          icon: const Icon(Icons.lightbulb_outline_rounded),
          label: Text(
            'HINT ${SudokuModel.maximumHints - controller.model.hintsUsed}',
          ),
        ),
      ),
    ],
  );
}
