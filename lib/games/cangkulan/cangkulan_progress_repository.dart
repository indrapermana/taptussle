import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/match_options.dart';
import 'cangkulan_model.dart';

class CangkulanProgressRepository {
  CangkulanProgressRepository(this._preferences);

  static const _version = 1;
  static const _prefix = 'cangkulan.active.v1';

  final SharedPreferences _preferences;
  Future<void> _pendingWrite = Future.value();

  CangkulanModel? load(MatchOptions options) {
    final encoded = _preferences.getString(_key(options));
    if (encoded == null) return null;
    try {
      final data = jsonDecode(encoded);
      if (data is! Map<String, dynamic> ||
          data['version'] != _version ||
          data['signature'] != _signature(options)) {
        return null;
      }
      final hands = _decodeHands(data['hands']);
      final pile = _decodeCards(data['drawPile']);
      final currentTurns = _decodeTurns(data['currentTrickTurns']);
      final completed = _decodeCompletedTricks(data['completedTricks']);
      final currentPlayer = data['currentPlayer'];
      final trickLeader = data['trickLeader'];
      final winner = data['winner'];
      if (currentPlayer is! int ||
          trickLeader is! int ||
          (winner != null && winner is! int)) {
        return null;
      }
      final model = CangkulanModel.restore(
        CangkulanSnapshot(
          hands: hands,
          drawPile: pile,
          currentPlayer: currentPlayer,
          trickLeader: trickLeader,
          currentTrickTurns: currentTurns,
          completedTricks: completed,
          winner: winner as int?,
        ),
      );
      return model.participantCount == options.participants.length
          ? model
          : null;
    } on Object {
      return null;
    }
  }

  Future<void> save(MatchOptions options, CangkulanModel model) {
    if (model.isFinished) return clear(options);
    final snapshot = model.snapshot;
    final encoded = jsonEncode({
      'version': _version,
      'signature': _signature(options),
      'hands': snapshot.hands.map(_encodeCards).toList(),
      'drawPile': _encodeCards(snapshot.drawPile),
      'currentPlayer': snapshot.currentPlayer,
      'trickLeader': snapshot.trickLeader,
      'currentTrickTurns': snapshot.currentTrickTurns.map(_encodeTurn).toList(),
      'completedTricks': snapshot.completedTricks
          .map(_encodeCompletedTrick)
          .toList(),
      'winner': snapshot.winner,
    });
    return _enqueue(() async {
      if (!await _preferences.setString(_key(options), encoded)) {
        throw StateError('Could not save Cangkulan match');
      }
    });
  }

  Future<void> clear(MatchOptions options) => _enqueue(() async {
    if (!await _preferences.remove(_key(options))) {
      throw StateError('Could not clear Cangkulan match');
    }
  });

  Future<void> get completed => _pendingWrite;

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _pendingWrite.then((_) => action());
    _pendingWrite = result.catchError((Object _) {});
    return result;
  }

  static List<String> _encodeCards(List<CangkulanCard> cards) =>
      cards.map(_encodeCard).toList(growable: false);

  static String _encodeCard(CangkulanCard card) =>
      '${card.suit.index}:${card.rank.index}';

  static Map<String, Object?> _encodeTurn(CangkulanTrickTurn turn) => {
    'player': turn.player,
    'playedCard': turn.playedCard == null
        ? null
        : _encodeCard(turn.playedCard!),
    'drawnCards': _encodeCards(turn.drawnCards),
    'skipped': turn.skipped,
  };

  static Map<String, Object?> _encodeCompletedTrick(
    CangkulanCompletedTrick trick,
  ) => {
    'leader': trick.leader,
    'requiredSuit': trick.requiredSuit.index,
    'turns': trick.turns.map(_encodeTurn).toList(),
    'winner': trick.winner,
  };

  static List<List<CangkulanCard>> _decodeHands(Object? value) {
    if (value is! List) throw const FormatException('Invalid hands');
    return value.map(_decodeCards).toList(growable: false);
  }

  static List<CangkulanCard> _decodeCards(Object? value) {
    if (value is! List) throw const FormatException('Invalid cards');
    return value.map(_decodeCard).toList(growable: false);
  }

  static CangkulanCard _decodeCard(Object? value) {
    if (value is! String) throw const FormatException('Invalid card');
    final parts = value.split(':');
    if (parts.length != 2) throw const FormatException('Invalid card');
    final suit = int.tryParse(parts[0]);
    final rank = int.tryParse(parts[1]);
    if (suit == null ||
        rank == null ||
        suit < 0 ||
        suit >= CangkulanSuit.values.length ||
        rank < 0 ||
        rank >= CangkulanRank.values.length) {
      throw const FormatException('Invalid card');
    }
    return CangkulanCard(
      CangkulanSuit.values[suit],
      CangkulanRank.values[rank],
    );
  }

  static List<CangkulanTrickTurn> _decodeTurns(Object? value) {
    if (value is! List) throw const FormatException('Invalid turns');
    return value.map(_decodeTurn).toList(growable: false);
  }

  static CangkulanTrickTurn _decodeTurn(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid turn');
    }
    final player = value['player'];
    final skipped = value['skipped'];
    if (player is! int || skipped is! bool) {
      throw const FormatException('Invalid turn');
    }
    return CangkulanTrickTurn(
      player: player,
      playedCard: value['playedCard'] == null
          ? null
          : _decodeCard(value['playedCard']),
      drawnCards: _decodeCards(value['drawnCards']),
      skipped: skipped,
    );
  }

  static List<CangkulanCompletedTrick> _decodeCompletedTricks(Object? value) {
    if (value is! List) {
      throw const FormatException('Invalid completed tricks');
    }
    return value
        .map((raw) {
          if (raw is! Map<String, dynamic>) {
            throw const FormatException('Invalid completed trick');
          }
          final leader = raw['leader'];
          final suit = raw['requiredSuit'];
          final winner = raw['winner'];
          if (leader is! int ||
              suit is! int ||
              winner is! int ||
              suit < 0 ||
              suit >= CangkulanSuit.values.length) {
            throw const FormatException('Invalid completed trick');
          }
          return CangkulanCompletedTrick(
            leader: leader,
            requiredSuit: CangkulanSuit.values[suit],
            turns: _decodeTurns(raw['turns']),
            winner: winner,
          );
        })
        .toList(growable: false);
  }

  static String _key(MatchOptions options) => '$_prefix.${_signature(options)}';

  static String _signature(MatchOptions options) => options.participants
      .map(
        (participant) =>
            participant.isBot ? 'b-${participant.botDifficulty!.name}' : 'h',
      )
      .join('_');
}
