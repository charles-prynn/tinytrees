part of '../player_state.dart';

class PlayerAction {
  const PlayerAction({
    required this.id,
    required this.type,
    required this.entityId,
    required this.status,
    required this.startedAt,
    required this.endsAt,
    required this.nextTickAt,
    required this.tickIntervalMs,
    required this.metadata,
    required this.updatedAt,
  });

  final String id;
  final String type;
  final String? entityId;
  final String status;
  final DateTime startedAt;
  final DateTime endsAt;
  final DateTime nextTickAt;
  final int tickIntervalMs;
  final Map<String, dynamic> metadata;
  final DateTime? updatedAt;

  factory PlayerAction.fromJson(Map<String, dynamic> json) {
    return PlayerAction(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      entityId: json['entity_id'] as String?,
      status: json['status'] as String? ?? '',
      startedAt:
          DateTime.tryParse(json['started_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      endsAt:
          DateTime.tryParse(json['ends_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      nextTickAt:
          DateTime.tryParse(json['next_tick_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      tickIntervalMs: (json['tick_interval_ms'] as num?)?.toInt() ?? 0,
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map? ?? const {},
      ),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }

  String get rewardItemKey => metadata['reward_item_key'] as String? ?? 'wood';

  double progress(DateTime now) {
    final total = endsAt.difference(startedAt).inMilliseconds;
    if (total <= 0) {
      return 1;
    }
    final elapsed = now.difference(startedAt).inMilliseconds;
    return (elapsed / total).clamp(0, 1).toDouble();
  }
}
