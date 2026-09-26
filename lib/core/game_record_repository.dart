import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_record_definition.dart';

class GameRecordKey {
  const GameRecordKey({
    required this.gameId,
    required this.recordType,
    required this.variant,
  });

  final String gameId;
  final String recordType;
  final String variant;

  @override
  bool operator ==(Object other) =>
      other is GameRecordKey &&
      other.gameId == gameId &&
      other.recordType == recordType &&
      other.variant == variant;

  @override
  int get hashCode => Object.hash(gameId, recordType, variant);
}

class GameRecord {
  GameRecord({
    required this.key,
    required DateTime completedAt,
    required Map<String, num> metrics,
  }) : completedAt = completedAt.toLocal(),
       metrics = Map.unmodifiable(Map<String, num>.of(metrics));

  final GameRecordKey key;

  /// Stored as local wall-clock time because daily and weekly records use the
  /// device's local calendar rather than a server-defined time zone.
  final DateTime completedAt;
  final Map<String, num> metrics;

  Map<String, Object> toJson() => {
    'gameId': key.gameId,
    'recordType': key.recordType,
    'variant': key.variant,
    'completedAt': completedAt.toIso8601String(),
    'metrics': metrics,
  };

  static GameRecord? tryParse(Object? source) {
    if (source is! Map) return null;
    final gameId = source['gameId'];
    final recordType = source['recordType'];
    final variant = source['variant'];
    final timestamp = source['completedAt'];
    final rawMetrics = source['metrics'];
    if (gameId is! String ||
        recordType is! String ||
        variant is! String ||
        timestamp is! String ||
        rawMetrics is! Map) {
      return null;
    }
    if (gameId.trim().isEmpty ||
        recordType.trim().isEmpty ||
        variant.trim().isEmpty ||
        rawMetrics.isEmpty) {
      return null;
    }
    final completedAt = DateTime.tryParse(timestamp);
    if (completedAt == null) return null;
    final metrics = <String, num>{};
    for (final entry in rawMetrics.entries) {
      if (entry.key is! String || entry.value is! num) return null;
      final value = entry.value as num;
      if (!value.isFinite || value < 0) return null;
      metrics[entry.key as String] = value;
    }
    return GameRecord(
      key: GameRecordKey(
        gameId: gameId,
        recordType: recordType,
        variant: variant,
      ),
      completedAt: completedAt,
      metrics: metrics,
    );
  }
}

class RankedGameRecord {
  const RankedGameRecord({required this.rank, required this.record});

  final int rank;
  final GameRecord record;
}

class GameRecordBests {
  const GameRecordBests({this.daily, this.weekly, this.overall});

  final RankedGameRecord? daily;
  final RankedGameRecord? weekly;
  final RankedGameRecord? overall;
}

class GameRecordRepository extends ChangeNotifier {
  GameRecordRepository(this._preferences)
    : _records = _readRecords(_preferences);

  static const storageKey = 'gameRecords.v1';

  final SharedPreferences _preferences;
  List<GameRecord> _records;
  Future<void> _pendingWrite = Future.value();

  List<GameRecord> recordsFor(GameRecordKey key) =>
      List.unmodifiable(_records.where((record) => record.key == key));

  Future<void> addRecord({
    required GameRecordDefinition definition,
    required GameRecord record,
  }) => _write(() async {
    _validateKey(record.key);
    _validateMetrics(definition, record.metrics);
    final next = List<GameRecord>.of(_records)..add(record);
    final encoded = jsonEncode(next.map((entry) => entry.toJson()).toList());
    if (!await _preferences.setString(storageKey, encoded)) {
      throw StateError('Could not save game record');
    }
    _records = next;
    notifyListeners();
  });

  List<RankedGameRecord> rankedRecords({
    required GameRecordKey key,
    required GameRecordDefinition definition,
  }) {
    _validateKey(key);
    final records = recordsFor(key).toList();
    for (final record in records) {
      _validateMetrics(definition, record.metrics);
    }
    records.sort((left, right) {
      final metricOrder = _compareMetrics(definition, left, right);
      if (metricOrder != 0) return metricOrder;
      return left.completedAt.compareTo(right.completedAt);
    });

    final ranked = <RankedGameRecord>[];
    var currentRank = 0;
    GameRecord? previous;
    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      if (previous == null ||
          _compareMetrics(definition, previous, record) != 0) {
        currentRank = index + 1;
      }
      ranked.add(RankedGameRecord(rank: currentRank, record: record));
      previous = record;
    }
    return List.unmodifiable(ranked);
  }

  RankedGameRecord? bestRecord({
    required GameRecordKey key,
    required GameRecordDefinition definition,
  }) => rankedRecords(key: key, definition: definition).firstOrNull;

  GameRecordBests bests({
    required GameRecordKey key,
    required GameRecordDefinition definition,
    DateTime? now,
  }) {
    _validateKey(key);
    final localNow = (now ?? DateTime.now()).toLocal();
    final dayStart = DateTime(localNow.year, localNow.month, localNow.day);
    final nextDay = DateTime(localNow.year, localNow.month, localNow.day + 1);
    final weekStart = DateTime(
      localNow.year,
      localNow.month,
      localNow.day - (localNow.weekday - DateTime.monday),
    );
    final nextWeek = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 7,
    );
    final records = recordsFor(key);
    return GameRecordBests(
      daily: _bestFrom(
        records.where(
          (record) =>
              !record.completedAt.isBefore(dayStart) &&
              record.completedAt.isBefore(nextDay),
        ),
        definition,
      ),
      weekly: _bestFrom(
        records.where(
          (record) =>
              !record.completedAt.isBefore(weekStart) &&
              record.completedAt.isBefore(nextWeek),
        ),
        definition,
      ),
      overall: _bestFrom(records, definition),
    );
  }

  RankedGameRecord? _bestFrom(
    Iterable<GameRecord> records,
    GameRecordDefinition definition,
  ) {
    final candidates = records.toList();
    for (final record in candidates) {
      _validateMetrics(definition, record.metrics);
    }
    candidates.sort((left, right) {
      final metricOrder = _compareMetrics(definition, left, right);
      if (metricOrder != 0) return metricOrder;
      return left.completedAt.compareTo(right.completedAt);
    });
    if (candidates.isEmpty) return null;
    return RankedGameRecord(rank: 1, record: candidates.first);
  }

  Future<void> _write(Future<void> Function() action) {
    final result = _pendingWrite.then((_) => action());
    _pendingWrite = result.catchError((Object _) {});
    return result;
  }

  static List<GameRecord> _readRecords(SharedPreferences preferences) {
    final stored = preferences.get(storageKey);
    if (stored is! String) return [];
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List) return [];
      return decoded.map(GameRecord.tryParse).whereType<GameRecord>().toList();
    } on FormatException {
      return [];
    }
  }

  static void _validateKey(GameRecordKey key) {
    if (key.gameId.trim().isEmpty ||
        key.recordType.trim().isEmpty ||
        key.variant.trim().isEmpty) {
      throw ArgumentError('Record game, type, and variant cannot be empty');
    }
  }

  static void _validateMetrics(
    GameRecordDefinition definition,
    Map<String, num> metrics,
  ) {
    final definitions = definition.metrics;
    final expected = definitions.map((metric) => metric.id).toSet();
    if (expected.length != definitions.length ||
        expected.any((id) => id.trim().isEmpty)) {
      throw ArgumentError('Record metric IDs must be non-empty and unique');
    }
    if (metrics.keys.toSet().length != expected.length ||
        !metrics.keys.toSet().containsAll(expected) ||
        metrics.values.any((value) => !value.isFinite || value < 0)) {
      throw ArgumentError.value(
        metrics,
        'metrics',
        'Provide one finite non-negative value for every record metric',
      );
    }
  }

  static int _compareMetrics(
    GameRecordDefinition definition,
    GameRecord left,
    GameRecord right,
  ) {
    for (final metric in definition.metrics) {
      final comparison = left.metrics[metric.id]!.compareTo(
        right.metrics[metric.id]!,
      );
      if (comparison == 0) continue;
      return metric.sortOrder == RecordSortOrder.higherIsBetter
          ? -comparison
          : comparison;
    }
    return 0;
  }
}
