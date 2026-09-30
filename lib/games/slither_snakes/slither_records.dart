import '../../core/game_record_definition.dart';

final slitherRecordDefinition = GameRecordDefinition(
  primaryMetric: const RecordMetricDefinition(
    id: 'score',
    label: 'Score',
    format: RecordMetricFormat.integer,
    sortOrder: RecordSortOrder.higherIsBetter,
  ),
  tieBreakers: const [
    RecordMetricDefinition(
      id: 'survivalTime',
      label: 'Survival',
      format: RecordMetricFormat.duration,
      sortOrder: RecordSortOrder.higherIsBetter,
    ),
  ],
);
