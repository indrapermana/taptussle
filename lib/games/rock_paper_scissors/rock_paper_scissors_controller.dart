import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'rock_paper_scissors_bot.dart';
import 'rock_paper_scissors_model.dart';

enum RockPaperScissorsRoundPhase { choosing, handoff, botThinking, reveal }

enum RockPaperScissorsSelectionResult { accepted, unavailable }

class RockPaperScissorsController extends ChangeNotifier {
  RockPaperScissorsController({
    required this.session,
    Random? random,
    this.botThinkDelay,
    this.finalRevealDelay = Duration.zero,
  }) : _random = random ?? Random(),
       model = RockPaperScissorsModel(
         winningScore: session.options.winningScore,
       ) {
    bot = session.options.mode == PlayMode.bot
        ? RockPaperScissorsBot(
            difficulty: session.options.botDifficulty!,
            random: _random,
          )
        : null;
    session.addListener(_syncSession);
    _syncSession();
  }

  final MatchSession session;
  final Random _random;
  final Duration? botThinkDelay;
  final Duration finalRevealDelay;
  final RockPaperScissorsModel model;
  late final RockPaperScissorsBot? bot;

  Timer? _botTimer;
  Timer? _resultTimer;
  var _phase = RockPaperScissorsRoundPhase.choosing;
  RockPaperScissorsRoundPhase get phase => _phase;
  var _activePlayer = 0;
  int get activePlayer => _activePlayer;
  var _roundStarter = 0;
  final List<RockPaperScissorsChoice?> _pendingChoices = [null, null];
  var _observedMatchRound = 0;
  var _observedPhase = MatchPhase.ready;
  var _hasStartedMatch = false;
  var _disposed = false;

  bool get isBotThinking => _botTimer?.isActive ?? false;
  bool get acceptsChoice =>
      !_disposed &&
      session.phase == MatchPhase.playing &&
      _phase == RockPaperScissorsRoundPhase.choosing &&
      session.options.participants[_activePlayer].isBot == false;

  bool hasLockedChoice(int player) => _pendingChoices[player] != null;

  RockPaperScissorsSelectionResult selectChoice(
    RockPaperScissorsChoice choice,
  ) {
    if (!acceptsChoice) return RockPaperScissorsSelectionResult.unavailable;
    _pendingChoices[_activePlayer] = choice;
    if (session.options.mode == PlayMode.bot) {
      _phase = RockPaperScissorsRoundPhase.botThinking;
      _scheduleBotChoice();
    } else if (_pendingChoices.every((choice) => choice != null)) {
      _resolveRound();
    } else {
      _activePlayer = 1 - _activePlayer;
      _phase = RockPaperScissorsRoundPhase.handoff;
    }
    notifyListeners();
    return RockPaperScissorsSelectionResult.accepted;
  }

  bool confirmHandoff() {
    if (_disposed ||
        session.phase != MatchPhase.playing ||
        _phase != RockPaperScissorsRoundPhase.handoff) {
      return false;
    }
    _phase = RockPaperScissorsRoundPhase.choosing;
    notifyListeners();
    return true;
  }

  bool startNextRound() {
    if (_disposed ||
        session.phase != MatchPhase.playing ||
        model.isFinished ||
        _phase != RockPaperScissorsRoundPhase.reveal) {
      return false;
    }
    _pendingChoices.fillRange(0, _pendingChoices.length, null);
    if (session.options.mode == PlayMode.friend) {
      _roundStarter = 1 - _roundStarter;
    }
    _activePlayer = session.options.mode == PlayMode.bot ? 0 : _roundStarter;
    _phase = RockPaperScissorsRoundPhase.choosing;
    notifyListeners();
    return true;
  }

  void _scheduleBotChoice() {
    if (_disposed ||
        session.phase != MatchPhase.playing ||
        _phase != RockPaperScissorsRoundPhase.botThinking ||
        _botTimer != null) {
      return;
    }
    _botTimer = Timer(botThinkDelay ?? _naturalThinkDelay(), _performBotChoice);
  }

  Duration _naturalThinkDelay() {
    final (minimum, variation) = switch (session.options.botDifficulty!) {
      BotDifficulty.easy => (900, 500),
      BotDifficulty.normal => (700, 400),
      BotDifficulty.hard => (550, 300),
    };
    return Duration(milliseconds: minimum + _random.nextInt(variation));
  }

  void _performBotChoice() {
    _botTimer = null;
    if (_disposed ||
        session.phase != MatchPhase.playing ||
        _phase != RockPaperScissorsRoundPhase.botThinking) {
      return;
    }
    _pendingChoices[1] = bot!.chooseChoice();
    _resolveRound();
  }

  void _resolveRound() {
    final playerOneChoice = _pendingChoices[0];
    final playerTwoChoice = _pendingChoices[1];
    if (playerOneChoice == null || playerTwoChoice == null) return;

    model.playRound(playerOneChoice, playerTwoChoice);
    bot?.observeCompletedRound(playerOneChoice);
    _phase = RockPaperScissorsRoundPhase.reveal;
    notifyListeners();

    final winner = model.winner;
    if (winner == null) {
      session.reportScores(model.scores);
    } else {
      _scheduleFinalResult();
    }
  }

  void _scheduleFinalResult() {
    if (_disposed ||
        session.phase != MatchPhase.playing ||
        !model.isFinished ||
        _resultTimer != null) {
      return;
    }
    if (finalRevealDelay == Duration.zero) {
      _publishFinalResult();
      return;
    }
    _resultTimer = Timer(finalRevealDelay, () {
      _resultTimer = null;
      if (_disposed || session.phase != MatchPhase.playing) return;
      _publishFinalResult();
    });
  }

  void _publishFinalResult() {
    session.reportResult(
      outcome: MatchOutcome.winner,
      scores: model.scores,
      winner: model.winner!,
    );
  }

  void _syncSession() {
    if (_disposed) return;
    final roundChanged = session.round != _observedMatchRound;
    if (roundChanged) {
      _cancelTimers();
      _observedMatchRound = session.round;
      if (session.round > 0) {
        if (_hasStartedMatch) {
          model.startRematch();
        } else {
          model.reset();
          _hasStartedMatch = true;
        }
        bot?.reset();
        _roundStarter = 0;
        _activePlayer = 0;
        _pendingChoices.fillRange(0, _pendingChoices.length, null);
        _phase = RockPaperScissorsRoundPhase.choosing;
      }
    }

    final phaseChanged = session.phase != _observedPhase;
    _observedPhase = session.phase;
    if (session.phase != MatchPhase.playing) {
      _cancelTimers();
    } else if ((roundChanged || phaseChanged) && model.isFinished) {
      _scheduleFinalResult();
    } else if ((roundChanged || phaseChanged) &&
        _phase == RockPaperScissorsRoundPhase.botThinking) {
      _scheduleBotChoice();
    }
    if (roundChanged || phaseChanged) notifyListeners();
  }

  void _cancelBotChoice() {
    _botTimer?.cancel();
    _botTimer = null;
  }

  void _cancelTimers() {
    _cancelBotChoice();
    _resultTimer?.cancel();
    _resultTimer = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    session.removeListener(_syncSession);
    _cancelTimers();
    super.dispose();
  }
}
