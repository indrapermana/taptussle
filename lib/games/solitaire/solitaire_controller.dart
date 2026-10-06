import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/match_session.dart';
import 'solitaire_model.dart';

enum SolitaireInteractionResult {
  selected,
  selectionCleared,
  moved,
  drew,
  recycled,
  undone,
  invalid,
  inputLocked,
  completed,
}

enum SolitaireSelectionType { waste, tableau, foundation }

class SolitaireSelection {
  const SolitaireSelection._({
    required this.type,
    this.pile,
    this.cardIndex,
    this.suit,
  });

  const SolitaireSelection.waste() : this._(type: SolitaireSelectionType.waste);

  const SolitaireSelection.tableau(int pile, int cardIndex)
    : this._(
        type: SolitaireSelectionType.tableau,
        pile: pile,
        cardIndex: cardIndex,
      );

  const SolitaireSelection.foundation(SolitaireSuit suit)
    : this._(type: SolitaireSelectionType.foundation, suit: suit);

  final SolitaireSelectionType type;
  final int? pile;
  final int? cardIndex;
  final SolitaireSuit? suit;
}

class SolitaireController extends ChangeNotifier {
  SolitaireController({
    SolitaireModel? initialModel,
    SolitaireDrawMode drawMode = SolitaireDrawMode.drawOne,
    this.session,
    DateTime Function()? now,
    this.clockTick = const Duration(seconds: 1),
    this.animationDuration = const Duration(milliseconds: 220),
  }) : model = initialModel ?? SolitaireModel.newGame(drawMode: drawMode),
       _now = now ?? DateTime.now {
    session?.addListener(_syncSession);
    _observedPhase = session?.phase ?? MatchPhase.playing;
    if (_observedPhase == MatchPhase.playing) _startClock();
  }

  SolitaireModel model;
  final MatchSession? session;
  final DateTime Function() _now;
  final Duration clockTick;
  final Duration animationDuration;
  Timer? _clockTimer;
  Timer? _animationTimer;
  DateTime? _activeStartedAt;
  Duration _elapsedBeforeActive = Duration.zero;
  MatchPhase _observedPhase = MatchPhase.ready;
  SolitaireSelection? _selection;
  SolitaireHint? _shownHint;
  bool _disposed = false;
  bool _animating = false;

  SolitaireSelection? get selection => _selection;
  SolitaireHint? get shownHint => _shownHint;
  bool get isAnimating => _animating;
  bool get isPaused => session?.phase == MatchPhase.paused;
  bool get acceptsInput =>
      !_disposed &&
      !_animating &&
      !model.isComplete &&
      (session == null || session!.phase == MatchPhase.playing);
  Duration get elapsed =>
      _elapsedBeforeActive +
      (_activeStartedAt == null
          ? Duration.zero
          : _now().difference(_activeStartedAt!));
  String get elapsedLabel {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  SolitaireInteractionResult drawOrRecycle() {
    if (!acceptsInput) return _lockedResult;
    final recycling = model.stock.isEmpty && model.waste.isNotEmpty;
    final result = model.drawOrRecycle();
    if (!result.accepted) return SolitaireInteractionResult.invalid;
    _accept(result);
    return recycling
        ? SolitaireInteractionResult.recycled
        : SolitaireInteractionResult.drew;
  }

  SolitaireInteractionResult tapWaste() {
    if (!acceptsInput) return _lockedResult;
    if (model.wasteTop == null) return SolitaireInteractionResult.invalid;
    if (_selection?.type == SolitaireSelectionType.waste) {
      return _clearSelection();
    }
    _selection = const SolitaireSelection.waste();
    _shownHint = null;
    notifyListeners();
    return SolitaireInteractionResult.selected;
  }

  SolitaireInteractionResult tapFoundation(SolitaireSuit suit) {
    if (!acceptsInput) return _lockedResult;
    final selected = _selection;
    if (selected == null) {
      if (model.foundations[suit]!.isEmpty) {
        return SolitaireInteractionResult.invalid;
      }
      _selection = SolitaireSelection.foundation(suit);
      _shownHint = null;
      notifyListeners();
      return SolitaireInteractionResult.selected;
    }
    if (selected.type == SolitaireSelectionType.foundation &&
        selected.suit == suit) {
      return _clearSelection();
    }
    return moveSelectionToFoundation();
  }

  SolitaireInteractionResult tapTableau(int pile, {int? cardIndex}) {
    if (!acceptsInput) return _lockedResult;
    if (pile < 0 || pile >= SolitaireModel.tableauPileCount) {
      return SolitaireInteractionResult.invalid;
    }
    final selected = _selection;
    if (selected != null) {
      if (selected.type == SolitaireSelectionType.tableau &&
          selected.pile == pile &&
          (cardIndex == null || selected.cardIndex == cardIndex)) {
        return _clearSelection();
      }
      return moveSelectionToTableau(pile);
    }

    final source = model.tableau[pile];
    if (source.isEmpty) return SolitaireInteractionResult.invalid;
    final index = cardIndex ?? source.length - 1;
    if (index < 0 || index >= source.length || !source[index].isFaceUp) {
      return SolitaireInteractionResult.invalid;
    }
    _selection = SolitaireSelection.tableau(pile, index);
    _shownHint = null;
    notifyListeners();
    return SolitaireInteractionResult.selected;
  }

  SolitaireInteractionResult moveSelectionToTableau(int destination) {
    if (!acceptsInput) return _lockedResult;
    final selected = _selection;
    if (selected == null) return SolitaireInteractionResult.invalid;
    final result = switch (selected.type) {
      SolitaireSelectionType.waste => model.moveWasteToTableau(destination),
      SolitaireSelectionType.tableau => model.moveTableauToTableau(
        source: selected.pile!,
        cardIndex: selected.cardIndex!,
        destination: destination,
      ),
      SolitaireSelectionType.foundation => model.moveFoundationToTableau(
        selected.suit!,
        destination,
      ),
    };
    return _acceptMove(result);
  }

  SolitaireInteractionResult moveSelectionToFoundation() {
    if (!acceptsInput) return _lockedResult;
    final selected = _selection;
    if (selected == null) return SolitaireInteractionResult.invalid;
    final result = switch (selected.type) {
      SolitaireSelectionType.waste => model.moveWasteToFoundation(),
      SolitaireSelectionType.tableau =>
        selected.cardIndex == model.tableau[selected.pile!].length - 1
            ? model.moveTableauToFoundation(selected.pile!)
            : SolitaireMoveResult(
                status: SolitaireMoveStatus.illegalDestination,
                model: model,
              ),
      SolitaireSelectionType.foundation => SolitaireMoveResult(
        status: SolitaireMoveStatus.illegalDestination,
        model: model,
      ),
    };
    return _acceptMove(result);
  }

  SolitaireInteractionResult dragWasteToTableau(int destination) {
    if (!acceptsInput) return _lockedResult;
    _selection = const SolitaireSelection.waste();
    return moveSelectionToTableau(destination);
  }

  SolitaireInteractionResult dragTableauToTableau({
    required int source,
    required int cardIndex,
    required int destination,
  }) {
    if (!acceptsInput) return _lockedResult;
    if (source < 0 || source >= SolitaireModel.tableauPileCount) {
      return SolitaireInteractionResult.invalid;
    }
    _selection = SolitaireSelection.tableau(source, cardIndex);
    return moveSelectionToTableau(destination);
  }

  SolitaireInteractionResult dragFoundationToTableau(
    SolitaireSuit suit,
    int destination,
  ) {
    if (!acceptsInput) return _lockedResult;
    _selection = SolitaireSelection.foundation(suit);
    return moveSelectionToTableau(destination);
  }

  SolitaireInteractionResult dragWasteToFoundation() {
    if (!acceptsInput) return _lockedResult;
    _selection = const SolitaireSelection.waste();
    return moveSelectionToFoundation();
  }

  SolitaireInteractionResult dragTableauToFoundation(int source) {
    if (!acceptsInput) return _lockedResult;
    if (source < 0 || source >= SolitaireModel.tableauPileCount) {
      return SolitaireInteractionResult.invalid;
    }
    final pile = model.tableau[source];
    if (pile.isEmpty) return SolitaireInteractionResult.invalid;
    _selection = SolitaireSelection.tableau(source, pile.length - 1);
    return moveSelectionToFoundation();
  }

  bool undo() {
    if (!acceptsInput || !model.canUndo) return false;
    model = model.undo();
    _selection = null;
    _shownHint = null;
    notifyListeners();
    return true;
  }

  SolitaireHint? requestHint() {
    if (!acceptsInput) return null;
    _selection = null;
    _shownHint = model.hint;
    notifyListeners();
    return _shownHint;
  }

  SolitaireInteractionResult _acceptMove(SolitaireMoveResult result) {
    if (!result.accepted) {
      _selection = null;
      notifyListeners();
      return SolitaireInteractionResult.invalid;
    }
    _accept(result);
    return model.isComplete
        ? SolitaireInteractionResult.completed
        : SolitaireInteractionResult.moved;
  }

  void _accept(SolitaireMoveResult result) {
    model = result.model;
    _selection = null;
    _shownHint = null;
    if (model.isComplete) _stopClock();
    _beginAnimation();
  }

  SolitaireInteractionResult _clearSelection() {
    _selection = null;
    notifyListeners();
    return SolitaireInteractionResult.selectionCleared;
  }

  SolitaireInteractionResult get _lockedResult => model.isComplete
      ? SolitaireInteractionResult.completed
      : SolitaireInteractionResult.inputLocked;

  void _beginAnimation() {
    _animationTimer?.cancel();
    if (animationDuration == Duration.zero) {
      _animating = false;
      notifyListeners();
      return;
    }
    _animating = true;
    notifyListeners();
    _animationTimer = Timer(animationDuration, () {
      _animationTimer = null;
      if (_disposed) return;
      _animating = false;
      notifyListeners();
    });
  }

  void _syncSession() {
    if (_disposed || session == null) return;
    final next = session!.phase;
    if (_observedPhase == MatchPhase.playing && next != MatchPhase.playing) {
      _stopClock();
      _animationTimer?.cancel();
      _animationTimer = null;
      _animating = false;
      _selection = null;
    } else if (_observedPhase != MatchPhase.playing &&
        next == MatchPhase.playing) {
      _startClock();
    }
    _observedPhase = next;
    notifyListeners();
  }

  void _startClock() {
    _activeStartedAt ??= _now();
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(clockTick, (_) {
      if (!_disposed &&
          (session == null || session!.phase == MatchPhase.playing)) {
        notifyListeners();
      }
    });
  }

  void _stopClock() {
    final started = _activeStartedAt;
    if (started != null) _elapsedBeforeActive += _now().difference(started);
    _activeStartedAt = null;
    _clockTimer?.cancel();
    _clockTimer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _animationTimer?.cancel();
    _stopClock();
    session?.removeListener(_syncSession);
    super.dispose();
  }
}
