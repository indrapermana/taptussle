import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/match_options.dart';
import 'ludo_model.dart';

class LudoProgressSnapshot {
  const LudoProgressSnapshot({
    required this.tokenProgress,
    required this.currentPlayer,
    required this.standings,
    required this.pendingRoll,
  });

  final List<List<int>> tokenProgress;
  final int currentPlayer;
  final List<int> standings;
  final int? pendingRoll;

  LudoModel restoreModel(LudoDiceRoller diceRoller) => LudoModel.fromState(
    playerCount: tokenProgress.length,
    diceRoller: diceRoller,
    tokenProgress: tokenProgress,
    currentPlayer: currentPlayer,
    standings: standings,
    pendingRoll: pendingRoll,
  );
}

class LudoProgressRepository {
  LudoProgressRepository(this._preferences);

  static const _version = 2;
  static const _prefix = 'ludo.active.v2';

  final SharedPreferences _preferences;
  Future<void> _pendingWrite = Future.value();

  LudoProgressSnapshot? load(MatchOptions options) {
    final encoded = _preferences.getString(_key(options));
    if (encoded == null) return null;
    try {
      final data = jsonDecode(encoded);
      if (data is! Map<String, dynamic> ||
          data['version'] != _version ||
          data['signature'] != _signature(options)) {
        return null;
      }
      final rawTokens = data['tokenProgress'];
      final rawStandings = data['standings'];
      if (rawTokens is! List || rawStandings is! List) return null;
      final tokens = <List<int>>[];
      for (final row in rawTokens) {
        if (row is! List || row.any((value) => value is! int)) return null;
        tokens.add(row.cast<int>().toList(growable: false));
      }
      if (rawStandings.any((value) => value is! int)) return null;
      final currentPlayer = data['currentPlayer'];
      final pendingRoll = data['pendingRoll'];
      if (currentPlayer is! int ||
          (pendingRoll != null && pendingRoll is! int)) {
        return null;
      }
      final snapshot = LudoProgressSnapshot(
        tokenProgress: tokens,
        currentPlayer: currentPlayer,
        standings: rawStandings.cast<int>().toList(growable: false),
        pendingRoll: pendingRoll as int?,
      );
      snapshot.restoreModel(() => 1);
      return snapshot;
    } on Object {
      return null;
    }
  }

  Future<void> save(MatchOptions options, LudoModel model) {
    if (model.isFinished) return clear(options);
    final encoded = jsonEncode({
      'version': _version,
      'signature': _signature(options),
      'tokenProgress': model.tokenProgress,
      'currentPlayer': model.currentPlayer,
      'standings': model.standings,
      'pendingRoll': model.pendingRoll,
    });
    return _enqueue(() async {
      if (!await _preferences.setString(_key(options), encoded)) {
        throw StateError('Could not save Ludo match');
      }
    });
  }

  Future<void> clear(MatchOptions options) => _enqueue(() async {
    if (!await _preferences.remove(_key(options))) {
      throw StateError('Could not clear Ludo match');
    }
  });

  Future<void> get completed => _pendingWrite;

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _pendingWrite.then((_) => action());
    _pendingWrite = result.catchError((Object _) {});
    return result;
  }

  static String _key(MatchOptions options) => '$_prefix.${_signature(options)}';

  static String _signature(MatchOptions options) => options.participants
      .map(
        (participant) =>
            participant.isBot ? 'b-${participant.botDifficulty!.name}' : 'h',
      )
      .join('_');
}
