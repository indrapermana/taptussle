import 'dart:async';

import 'package:flutter/foundation.dart';

import 'nuts_and_bolts_levels.dart';
import 'nuts_and_bolts_model.dart';

enum NutsAndBoltsTapResult {
  selected,
  selectionCleared,
  selectionChanged,
  moved,
  invalid,
  inputLocked,
  completed,
}

class NutsAndBoltsController extends ChangeNotifier {
  NutsAndBoltsController({
    required this.level,
    NutsAndBoltsModel? initialModel,
    this.animationDuration = const Duration(milliseconds: 300),
  }) : model = initialModel ?? level.createModel() {
    if (model.capacity != level.capacity ||
        model.boltCount != level.bolts.length) {
      throw ArgumentError('Initial model does not match the level shape');
    }
  }

  final NutsAndBoltsLevel level;
  final Duration animationDuration;
  NutsAndBoltsModel model;
  Timer? _animationTimer;
  int? _selectedBolt;
  NutsAndBoltsMove? _animatingMove;
  NutsAndBoltsMove? _hintMove;
  bool _disposed = false;

  int? get selectedBolt => _selectedBolt;
  NutsAndBoltsMove? get animatingMove => _animatingMove;
  NutsAndBoltsMove? get hintMove => _hintMove;
  bool get isAnimating => _animatingMove != null;
  bool get acceptsInput => !isAnimating && !model.isComplete;

  bool isLegalDestination(int bolt) =>
      _selectedBolt != null && model.canMove(_selectedBolt!, bolt);

  NutsAndBoltsTapResult tapBolt(int bolt) {
    if (bolt < 0 || bolt >= model.boltCount) {
      return NutsAndBoltsTapResult.invalid;
    }
    if (model.isComplete) return NutsAndBoltsTapResult.completed;
    if (!acceptsInput) return NutsAndBoltsTapResult.inputLocked;

    final selected = _selectedBolt;
    if (selected == null) {
      if (model.bolts[bolt].isEmpty) return NutsAndBoltsTapResult.invalid;
      _selectedBolt = bolt;
      _hintMove = null;
      notifyListeners();
      return NutsAndBoltsTapResult.selected;
    }
    if (selected == bolt) {
      _selectedBolt = null;
      notifyListeners();
      return NutsAndBoltsTapResult.selectionCleared;
    }

    final result = model.move(selected, bolt);
    if (!result.accepted) {
      if (model.bolts[bolt].isNotEmpty) {
        _selectedBolt = bolt;
        _hintMove = null;
        notifyListeners();
        return NutsAndBoltsTapResult.selectionChanged;
      }
      return NutsAndBoltsTapResult.invalid;
    }

    model = result.model;
    _selectedBolt = null;
    _hintMove = null;
    _animatingMove = result.move;
    notifyListeners();
    _animationTimer?.cancel();
    if (animationDuration == Duration.zero) {
      _finishAnimation();
    } else {
      _animationTimer = Timer(animationDuration, _finishAnimation);
    }
    return NutsAndBoltsTapResult.moved;
  }

  bool undo() {
    if (!acceptsInput || !model.canUndo) return false;
    model = model.undo();
    _selectedBolt = null;
    _hintMove = null;
    notifyListeners();
    return true;
  }

  bool restart() {
    if (!acceptsInput || model.moveCount == 0) return false;
    model = model.restart();
    _selectedBolt = null;
    _hintMove = null;
    notifyListeners();
    return true;
  }

  NutsAndBoltsMove? requestHint() {
    if (!acceptsInput) return null;
    _hintMove = model.hint;
    _selectedBolt = null;
    notifyListeners();
    return _hintMove;
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
