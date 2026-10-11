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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 620;
            return Column(
              children: [
                _StatusBar(controller: controller, compact: compact),
                SizedBox(height: compact ? 5 : 8),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _Grid(controller: controller),
                    ),
                  ),
                ),
                SizedBox(height: compact ? 5 : 8),
                _NumberPad(controller: controller, compact: compact),
                SizedBox(height: compact ? 4 : 6),
                _ActionBar(controller: controller),
              ],
            );
          },
        ),
      );
    },
  );
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller, required this.compact});

  final SudokuController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final puzzle = controller.model.puzzle;
    final elapsed = controller.elapsed;
    final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final selected = controller.selectedCell;
    final prompt = selected == null
        ? 'PICK AN EMPTY SQUARE'
        : controller.model.isGiven(selected)
        ? 'THIS NUMBER IS FIXED'
        : controller.notesMode
        ? 'ADD A LITTLE NOTE'
        : 'NOW PICK A NUMBER';
    return ArcadePanel(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 9,
      ),
      accent: controller.notesMode
          ? TapTussleColors.gold
          : TapTussleColors.electricBlue,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${puzzle.difficulty.name.toUpperCase()} • LEVEL ${puzzle.level}',
                  style: TextStyle(
                    fontFamily: 'Lilita One',
                    color: TapTussleColors.electricBlue,
                    fontSize: compact ? 12 : 14,
                    letterSpacing: .5,
                  ),
                ),
                Text(
                  prompt,
                  key: const ValueKey('sudoku-prompt'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Lilita One',
                    color: controller.notesMode
                        ? TapTussleColors.gold
                        : TapTussleColors.text,
                    fontSize: compact ? 14 : 17,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 15,
                    color: TapTussleColors.mutedText,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$minutes:$seconds',
                    key: const ValueKey('sudoku-timer'),
                    semanticsLabel:
                        'Elapsed time $minutes minutes $seconds seconds',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Text(
                '${controller.model.mistakes} MISTAKES',
                key: const ValueKey('sudoku-mistakes'),
                style: const TextStyle(
                  color: TapTussleColors.rivalRed,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
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
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: TapTussleColors.electricBlue.withValues(alpha: .2),
          blurRadius: 14,
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 9,
        ),
        itemCount: SudokuSolver.cellCount,
        itemBuilder: (context, cell) =>
            _Cell(controller: controller, cell: cell),
      ),
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
    final boxIsCool = (row ~/ 3 + column ~/ 3).isEven;
    final baseBackground = boxIsCool
        ? const Color(0xFFEAF7FF)
        : const Color(0xFFFFF4D8);
    final background = incorrect
        ? TapTussleColors.rivalRed.withValues(alpha: .25)
        : selected
        ? TapTussleColors.gold.withValues(alpha: .38)
        : sameValue
        ? TapTussleColors.electricBlue.withValues(alpha: .26)
        : related
        ? TapTussleColors.electricBlue.withValues(alpha: .11)
        : baseBackground;
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: background,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: TapTussleColors.gold.withValues(alpha: .7),
                        blurRadius: 8,
                        spreadRadius: -1,
                      ),
                    ]
                  : null,
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
                          fontFamily: 'Fredoka',
                          fontWeight: FontWeight.w800,
                          fontSize: 27,
                          shadows: selected
                              ? const [
                                  Shadow(color: Colors.white, blurRadius: 3),
                                ]
                              : null,
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
  const _NumberPad({required this.controller, required this.compact});

  final SudokuController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedCell;
    final canEnter = selected != null && !controller.model.isGiven(selected);
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 5.0;
        final buttonWidth = (constraints.maxWidth - gap * 4) / 5;
        final buttonHeight = compact ? 39.0 : 48.0;
        return SizedBox(
          height: buttonHeight * 2 + gap,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var value = 1; value <= 9; value++)
                SizedBox(
                  width: buttonWidth,
                  height: buttonHeight,
                  child: FilledButton(
                    key: ValueKey('sudoku-number-$value'),
                    style: FilledButton.styleFrom(
                      minimumSize: Size(buttonWidth, buttonHeight),
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    onPressed: !canEnter || _remaining(value) == 0
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$value',
                          style: TextStyle(
                            fontFamily: 'Lilita One',
                            fontSize: compact ? 19 : 23,
                            height: .9,
                          ),
                        ),
                        if (!compact)
                          Text(
                            '${_remaining(value)} left',
                            style: const TextStyle(fontSize: 9, height: 1),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  int _remaining(int value) =>
      9 - controller.model.values.where((entry) => entry == value).length;
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
