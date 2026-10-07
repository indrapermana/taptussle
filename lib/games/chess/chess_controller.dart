import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'chess_bot.dart';
import 'chess_model.dart';

enum ChessTapResult { selected, deselected, moved, promotionRequired, ignored }

/// Owns touch interaction and optional friend/bot match lifecycle.
class ChessController extends ChangeNotifier {
  ChessController({
    ChessModel? model,
    this.session,
    ChessBot? bot,
    Random? random,
    this.botThinkDelay,
  }) : model = model ?? ChessModel(),
       _random = random ?? Random() {
    final options = session?.options;
    this.bot =
        bot ??
        (options?.mode == PlayMode.bot
            ? ChessBot(difficulty: options!.botDifficulty!, random: _random)
            : null);
    session?.addListener(_syncSession);
    _syncSession();
  }

  final MatchSession? session;
  final Random _random;
  final Duration? botThinkDelay;
  late final ChessBot? bot;

  ChessModel model;
  int? selectedSquare;
  List<ChessMove> pendingPromotionMoves = const [];

  Timer? _botTimer;
  int _observedRound = 0;
  MatchPhase _observedPhase = MatchPhase.ready;
  bool _disposed = false;

  bool get isChoosingPromotion => pendingPromotionMoves.isNotEmpty;
  bool get isBotTurn =>
      bot != null && !model.isFinished && model.sideToMove == bot!.color;
  bool get isBotThinking => _botTimer?.isActive ?? false;
  bool get acceptsInput =>
      !_disposed &&
      !model.isFinished &&
      !isBotTurn &&
      (session == null || session!.phase == MatchPhase.playing);

  List<ChessMove> get selectedMoves =>
      selectedSquare == null ? const [] : model.legalMovesFrom(selectedSquare!);

  ChessTapResult tapSquare(int square) {
    if (!acceptsInput || isChoosingPromotion || !ChessModel.isSquare(square)) {
      return ChessTapResult.ignored;
    }

    final selected = selectedSquare;
    if (selected != null) {
      final matching = selectedMoves
          .where((move) => move.to == square)
          .toList();
      if (matching.length > 1) {
        pendingPromotionMoves = List.unmodifiable(matching);
        notifyListeners();
        return ChessTapResult.promotionRequired;
      }
      if (matching.length == 1) return _play(matching.single);
      if (square == selected) {
        selectedSquare = null;
        notifyListeners();
        return ChessTapResult.deselected;
      }
    }

    final piece = model.pieceAt(square);
    if (piece?.color == model.sideToMove &&
        model.legalMovesFrom(square).isNotEmpty) {
      selectedSquare = square;
      notifyListeners();
      return ChessTapResult.selected;
    }
    return ChessTapResult.ignored;
  }

  ChessTapResult choosePromotion(ChessPieceType type) {
    if (!acceptsInput || !isChoosingPromotion) return ChessTapResult.ignored;
    ChessMove? selected;
    for (final move in pendingPromotionMoves) {
      if (move.promotion == type) {
        selected = move;
        break;
      }
    }
    if (selected == null) return ChessTapResult.ignored;
    return _play(selected);
  }

  void cancelPromotion() {
    if (!acceptsInput || !isChoosingPromotion) return;
    pendingPromotionMoves = const [];
    notifyListeners();
  }

  ChessTapResult _play(ChessMove move) {
    final result = model.play(move);
    if (!result.accepted) return ChessTapResult.ignored;
    model = result.model;
    selectedSquare = null;
    pendingPromotionMoves = const [];
    notifyListeners();
    if (model.isFinished) {
      _publishResult();
    } else {
      _scheduleBotTurn();
    }
    return ChessTapResult.moved;
  }

  void _syncSession() {
    if (_disposed || session == null) return;
    final roundChanged = session!.round != _observedRound;
    if (roundChanged) {
      _cancelBotTurn();
      if (_observedRound > 0) model = ChessModel();
      _observedRound = session!.round;
      selectedSquare = null;
      pendingPromotionMoves = const [];
    }
    final phaseChanged = session!.phase != _observedPhase;
    _observedPhase = session!.phase;
    if (session!.phase != MatchPhase.playing) {
      _cancelBotTurn();
    } else if (roundChanged || phaseChanged) {
      _scheduleBotTurn();
    }
    if (roundChanged || phaseChanged) notifyListeners();
  }

  void _scheduleBotTurn() {
    if (_disposed ||
        !isBotTurn ||
        _botTimer != null ||
        (session != null && session!.phase != MatchPhase.playing)) {
      return;
    }
    _botTimer = Timer(botThinkDelay ?? _naturalThinkDelay(), _performBotMove);
    notifyListeners();
  }

  Duration _naturalThinkDelay() {
    final (minimum, variation) = switch (bot!.difficulty) {
      BotDifficulty.easy => (850, 550),
      BotDifficulty.normal => (700, 500),
      BotDifficulty.hard => (550, 450),
    };
    return Duration(milliseconds: minimum + _random.nextInt(variation));
  }

  void _performBotMove() {
    _botTimer = null;
    if (_disposed ||
        !isBotTurn ||
        (session != null && session!.phase != MatchPhase.playing)) {
      return;
    }
    final move = bot!.chooseMove(model);
    if (move == null) return;
    final result = model.play(move);
    if (!result.accepted) return;
    model = result.model;
    selectedSquare = null;
    pendingPromotionMoves = const [];
    notifyListeners();
    if (model.isFinished) _publishResult();
  }

  void _publishResult() {
    final currentSession = session;
    if (currentSession == null || currentSession.phase != MatchPhase.playing) {
      return;
    }
    final winner = model.winner;
    if (winner != null) {
      final participant = winner == ChessColor.white ? 0 : 1;
      currentSession.reportNonPointResult(
        winner: participant,
        scores: participant == 0 ? const [1, 0] : const [0, 1],
        details:
            '${currentSession.options.playerLabel(participant)} wins by checkmate. • Another round?',
      );
      return;
    }
    final reason = switch (model.drawReason) {
      ChessDrawReason.stalemate => 'Stalemate.',
      ChessDrawReason.insufficientMaterial =>
        'Neither side has enough material to checkmate.',
      ChessDrawReason.threefoldRepetition =>
        'The same position occurred three times.',
      ChessDrawReason.fiftyMoveRule =>
        'Fifty moves passed without a pawn move or capture.',
      null => 'The game is drawn.',
    };
    currentSession.reportNonPointResult(
      winner: null,
      scores: const [0, 0],
      details: '$reason • Another round?',
    );
  }

  void _cancelBotTurn() {
    _botTimer?.cancel();
    _botTimer = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    session?.removeListener(_syncSession);
    _cancelBotTurn();
    super.dispose();
  }
}
