import 'dart:async';

import 'package:flutter/foundation.dart';

import 'water_sort_levels.dart';
import 'water_sort_model.dart';
import 'water_sort_solver.dart';

enum WaterSortTapResult {
  selected,
  selectionCleared,
  selectionChanged,
  poured,
  invalid,
  inputLocked,
  completed,
}

class WaterSortController extends ChangeNotifier {
  WaterSortController({
    required this.level,
    WaterSortModel? initialModel,
    WaterSortSolver solver = const WaterSortSolver(),
    this.animationDuration = const Duration(milliseconds: 360),
  }) : model = initialModel ?? level.createModel(),
       _solver = solver {
    if (model.capacity != level.capacity ||
        model.tubeCount != level.tubes.length) {
      throw ArgumentError('Initial model does not match the level shape');
    }
  }

  final WaterSortLevel level;
  final Duration animationDuration;
  final WaterSortSolver _solver;
  WaterSortModel model;
  Timer? _animationTimer;
  bool _disposed = false;
  int? _selectedTube;
  WaterSortMove? _animatingMove;
  WaterSortMove? _hintMove;

  int? get selectedTube => _selectedTube;
  WaterSortMove? get animatingMove => _animatingMove;
  WaterSortMove? get hintMove => _hintMove;
  bool get isAnimating => _animatingMove != null;
  bool get acceptsInput => !isAnimating && !model.isComplete;

  WaterSortTapResult tapTube(int tube) {
    if (tube < 0 || tube >= model.tubeCount) {
      return WaterSortTapResult.invalid;
    }
    if (model.isComplete) return WaterSortTapResult.completed;
    if (isAnimating) return WaterSortTapResult.inputLocked;

    final selected = _selectedTube;
    if (selected == null) {
      if (model.tubes[tube].isEmpty) return WaterSortTapResult.invalid;
      _selectedTube = tube;
      _hintMove = null;
      notifyListeners();
      return WaterSortTapResult.selected;
    }
    if (selected == tube) {
      _selectedTube = null;
      notifyListeners();
      return WaterSortTapResult.selectionCleared;
    }

    final result = model.pour(selected, tube);
    if (!result.accepted) {
      if (model.tubes[tube].isNotEmpty) {
        _selectedTube = tube;
        _hintMove = null;
        notifyListeners();
        return WaterSortTapResult.selectionChanged;
      }
      return WaterSortTapResult.invalid;
    }

    model = result.model;
    _selectedTube = null;
    _hintMove = null;
    _animatingMove = result.move;
    notifyListeners();
    _animationTimer?.cancel();
    if (animationDuration == Duration.zero) {
      _finishAnimation();
    } else {
      _animationTimer = Timer(animationDuration, _finishAnimation);
    }
    return WaterSortTapResult.poured;
  }

  bool undo() {
    if (isAnimating || !model.canUndo) return false;
    model = model.undo();
    _selectedTube = null;
    _hintMove = null;
    notifyListeners();
    return true;
  }

  bool restart() {
    if (isAnimating || model.moveCount == 0) return false;
    model = model.restart();
    _selectedTube = null;
    _hintMove = null;
    notifyListeners();
    return true;
  }

  WaterSortMove? requestHint() {
    if (isAnimating || model.isComplete) return null;
    final solution = _solver.solve(model);
    _hintMove = solution == null || solution.moves.isEmpty
        ? null
        : solution.moves.first;
    _selectedTube = null;
    notifyListeners();
    return _hintMove;
  }

  void clearHint() {
    if (_hintMove == null) return;
    _hintMove = null;
    notifyListeners();
  }

  void _finishAnimation() {
    if (_disposed) return;
    _animationTimer = null;
    _animatingMove = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _animationTimer?.cancel();
    super.dispose();
  }
}
