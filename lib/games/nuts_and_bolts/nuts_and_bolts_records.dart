import '../../core/game_record_definition.dart';

final nutsAndBoltsRecordDefinition = GameRecordDefinition(
  primaryMetric: const RecordMetricDefinition(
    id: 'level',
    label: 'Level',
    format: RecordMetricFormat.integer,
    sortOrder: RecordSortOrder.higherIsBetter,
  ),
  tieBreakers: const [
    RecordMetricDefinition(
      id: 'moves',
      label: 'Moves',
      format: RecordMetricFormat.integer,
      sortOrder: RecordSortOrder.lowerIsBetter,
    ),
    RecordMetricDefinition(
      id: 'time',
      label: 'Time',
      format: RecordMetricFormat.duration,
      sortOrder: RecordSortOrder.lowerIsBetter,
    ),
  ],
);
