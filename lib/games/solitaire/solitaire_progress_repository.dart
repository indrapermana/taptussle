import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'solitaire_model.dart';

class SolitaireStats {
  const SolitaireStats({
    this.wins = 0,
    this.fastestMilliseconds,
    this.fewestMoves,
  });

  final int wins;
  final int? fastestMilliseconds;
  final int? fewestMoves;
}

class SolitaireProgressSnapshot {
  const SolitaireProgressSnapshot({
    required this.difficulty,
    required this.states,
    required this.elapsedMilliseconds,
  });

  final SolitaireDifficulty difficulty;
  final List<SolitaireStateSnapshot> states;
  final int elapsedMilliseconds;

  SolitaireModel restoreModel() =>
      SolitaireModel.restore(drawMode: difficulty.drawMode, snapshots: states);
}

class SolitaireProgressRepository {
  SolitaireProgressRepository(this._preferences);

  static const _version = 1;
  final SharedPreferences _preferences;
  Future<void> _pendingWrite = Future.value();

  String _activeKey(SolitaireDifficulty difficulty) =>
      'solitaire.active.${difficulty.name}.v1';
  String _statsKey(SolitaireDifficulty difficulty) =>
      'solitaire.stats.${difficulty.name}.v1';

  SolitaireProgressSnapshot? loadActive(SolitaireDifficulty difficulty) {
    final encoded = _preferences.getString(_activeKey(difficulty));
    if (encoded == null) return null;
    try {
      final data = jsonDecode(encoded);
      if (data is! Map<String, dynamic> ||
          data['version'] != _version ||
          data['difficulty'] != difficulty.name) {
        return null;
      }
      final rawStates = data['states'];
      if (rawStates is! List || rawStates.isEmpty) return null;
      final states = rawStates.map(_decodeState).toList(growable: false);
      final snapshot = SolitaireProgressSnapshot(
        difficulty: difficulty,
        states: List.unmodifiable(states),
        elapsedMilliseconds: _nonNegativeInteger(data['elapsedMilliseconds']),
      );
      if (snapshot.restoreModel().isComplete) return null;
      return snapshot;
    } on Object {
      return null;
    }
  }

  Future<void> saveActive({
    required SolitaireDifficulty difficulty,
    required SolitaireModel model,
    required Duration elapsed,
  }) {
    if (model.drawMode != difficulty.drawMode ||
        model.isComplete ||
        elapsed.isNegative) {
      throw ArgumentError('Active Solitaire progress is invalid');
    }
    final encoded = jsonEncode({
      'version': _version,
      'difficulty': difficulty.name,
      'states': model.snapshots.map(_encodeState).toList(),
      'elapsedMilliseconds': elapsed.inMilliseconds,
    });
    return _enqueue(() async {
      if (!await _preferences.setString(_activeKey(difficulty), encoded)) {
        throw StateError('Could not save Solitaire progress');
      }
    });
  }

  Future<void> clearActive(SolitaireDifficulty difficulty) =>
      _enqueue(() async {
        if (!await _preferences.remove(_activeKey(difficulty))) {
          throw StateError('Could not clear Solitaire progress');
        }
      });

  SolitaireStats stats(SolitaireDifficulty difficulty) {
    final encoded = _preferences.getString(_statsKey(difficulty));
    if (encoded == null) return const SolitaireStats();
    try {
      final data = jsonDecode(encoded);
      if (data is! Map<String, dynamic> ||
          data['version'] != _version ||
          data['difficulty'] != difficulty.name) {
        return const SolitaireStats();
      }
      return SolitaireStats(
        wins: _nonNegativeInteger(data['wins']),
        fastestMilliseconds: _nullableNonNegativeInteger(
          data['fastestMilliseconds'],
        ),
        fewestMoves: _nullableNonNegativeInteger(data['fewestMoves']),
      );
    } on Object {
      return const SolitaireStats();
    }
  }

  Future<void> recordWin({
    required SolitaireDifficulty difficulty,
    required int moves,
    required Duration elapsed,
  }) {
    if (moves < 0 || elapsed.isNegative) {
      throw ArgumentError('Win metrics cannot be negative');
    }
    return _enqueue(() async {
      final previous = stats(difficulty);
      final milliseconds = elapsed.inMilliseconds;
      final next = {
        'version': _version,
        'difficulty': difficulty.name,
        'wins': previous.wins + 1,
        'fastestMilliseconds': previous.fastestMilliseconds == null
            ? milliseconds
            : milliseconds < previous.fastestMilliseconds!
            ? milliseconds
            : previous.fastestMilliseconds,
        'fewestMoves': previous.fewestMoves == null
            ? moves
            : moves < previous.fewestMoves!
            ? moves
            : previous.fewestMoves,
      };
      if (!await _preferences.setString(
        _statsKey(difficulty),
        jsonEncode(next),
      )) {
        throw StateError('Could not save Solitaire win');
      }
      if (!await _preferences.remove(_activeKey(difficulty))) {
        throw StateError('Could not clear completed Solitaire deal');
      }
    });
  }

  Future<void> get completed => _pendingWrite;

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _pendingWrite.then((_) => action());
    _pendingWrite = result.catchError((Object _) {});
    return result;
  }

  static Map<String, Object> _encodeState(SolitaireStateSnapshot state) => {
    's': state.stock.map(_cardId).toList(),
    'w': state.waste.map(_cardId).toList(),
    't': [
      for (final pile in state.tableau)
        [
          for (final entry in pile)
            entry.isFaceUp ? _cardId(entry.card) : -_cardId(entry.card),
        ],
    ],
    'f': [
      for (final suit in SolitaireSuit.values)
        state.foundations[suit]?.length ?? 0,
    ],
    'm': state.moveCount,
    'p': state.score,
  };

  static SolitaireStateSnapshot _decodeState(Object? raw) {
    if (raw is! Map) throw const FormatException('Invalid saved state');
    final rawStock = raw['s'];
    final rawWaste = raw['w'];
    final rawTableau = raw['t'];
    final rawFoundations = raw['f'];
    if (rawStock is! List ||
        rawWaste is! List ||
        rawTableau is! List ||
        rawTableau.length != SolitaireModel.tableauPileCount ||
        rawFoundations is! List ||
        rawFoundations.length != SolitaireSuit.values.length) {
      throw const FormatException('Invalid saved piles');
    }
    final foundations = <SolitaireSuit, List<SolitaireCard>>{};
    for (
      var suitIndex = 0;
      suitIndex < SolitaireSuit.values.length;
      suitIndex++
    ) {
      final length = _nonNegativeInteger(rawFoundations[suitIndex]);
      if (length > SolitaireRank.values.length) {
        throw const FormatException('Invalid foundation length');
      }
      final suit = SolitaireSuit.values[suitIndex];
      foundations[suit] = [
        for (var rank = 0; rank < length; rank++)
          SolitaireCard(suit, SolitaireRank.values[rank]),
      ];
    }
    return SolitaireStateSnapshot(
      stock: rawStock.map(_decodeCard).toList(),
      waste: rawWaste.map(_decodeCard).toList(),
      tableau: [
        for (final rawPile in rawTableau)
          if (rawPile is List)
            [
              for (final rawCard in rawPile)
                SolitaireTableauCard(
                  _decodeCard(_signedCardId(rawCard).abs()),
                  isFaceUp: _signedCardId(rawCard) > 0,
                ),
            ]
          else
            throw const FormatException('Invalid tableau pile'),
      ],
      foundations: foundations,
      moveCount: _nonNegativeInteger(raw['m']),
      score: _nonNegativeInteger(raw['p']),
    );
  }

  static int _cardId(SolitaireCard card) =>
      card.suit.index * SolitaireRank.values.length + card.rank.index + 1;

  static SolitaireCard _decodeCard(Object? raw) {
    final id = _positiveInteger(raw);
    if (id > 52) throw const FormatException('Invalid card');
    final zeroBased = id - 1;
    return SolitaireCard(
      SolitaireSuit.values[zeroBased ~/ SolitaireRank.values.length],
      SolitaireRank.values[zeroBased % SolitaireRank.values.length],
    );
  }

  static int _signedCardId(Object? value) {
    if (value is! int || value == 0 || value < -52 || value > 52) {
      throw const FormatException('Expected a signed card ID');
    }
    return value;
  }

  static int _positiveInteger(Object? value) {
    if (value is! int || value < 1) {
      throw const FormatException('Expected a positive integer');
    }
    return value;
  }

  static int _nonNegativeInteger(Object? value) {
    if (value is! int || value < 0) {
      throw const FormatException('Expected a non-negative integer');
    }
    return value;
  }

  static int? _nullableNonNegativeInteger(Object? value) =>
      value == null ? null : _nonNegativeInteger(value);
}
