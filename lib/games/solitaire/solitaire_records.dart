import '../../core/game_record_definition.dart';

final solitaireRecordDefinition = GameRecordDefinition(
  recordType: 'win',
  primaryMetric: const RecordMetricDefinition(
    id: 'time',
    label: 'Fastest Win',
    format: RecordMetricFormat.duration,
    sortOrder: RecordSortOrder.lowerIsBetter,
  ),
  tieBreakers: const [
    RecordMetricDefinition(
      id: 'moves',
      label: 'Moves',
      format: RecordMetricFormat.integer,
      sortOrder: RecordSortOrder.lowerIsBetter,
    ),
  ],
);
