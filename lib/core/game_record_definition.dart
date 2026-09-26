enum RecordMetricFormat { integer, duration }

enum RecordSortOrder { higherIsBetter, lowerIsBetter }

class RecordMetricDefinition {
  const RecordMetricDefinition({
    required this.id,
    required this.label,
    required this.format,
    required this.sortOrder,
  });

  final String id;
  final String label;
  final RecordMetricFormat format;
  final RecordSortOrder sortOrder;
}

/// Metrics are compared in order, so later entries are tie-breakers.
class GameRecordDefinition {
  GameRecordDefinition({
    required this.primaryMetric,
    this.recordType = 'solo',
    List<RecordMetricDefinition> tieBreakers = const [],
  }) : tieBreakers = List.unmodifiable(tieBreakers);

  final String recordType;
  final RecordMetricDefinition primaryMetric;
  final List<RecordMetricDefinition> tieBreakers;

  List<RecordMetricDefinition> get metrics => [primaryMetric, ...tieBreakers];
}
