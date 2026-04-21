class MapPoint {
  const MapPoint({required this.x, required this.y});

  final int x;
  final int y;

  factory MapPoint.fromJson(Map<String, dynamic> json) {
    return MapPoint(
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlayerMovement {
  const PlayerMovement({
    required this.fromX,
    required this.fromY,
    required this.targetX,
    required this.targetY,
    required this.path,
    required this.startedAt,
    required this.arrivesAt,
    required this.speedTilesPerSecond,
  });

  final int fromX;
  final int fromY;
  final int targetX;
  final int targetY;
  final List<MapPoint> path;
  final DateTime startedAt;
  final DateTime arrivesAt;
  final double speedTilesPerSecond;

  factory PlayerMovement.fromJson(Map<String, dynamic> json) {
    final path = json['path'] as List<dynamic>? ?? const [];
    return PlayerMovement(
      fromX: (json['from_x'] as num?)?.toInt() ?? 0,
      fromY: (json['from_y'] as num?)?.toInt() ?? 0,
      targetX: (json['target_x'] as num?)?.toInt() ?? 0,
      targetY: (json['target_y'] as num?)?.toInt() ?? 0,
      path:
          path
              .map((point) => MapPoint.fromJson(point as Map<String, dynamic>))
              .toList(),
      startedAt:
          DateTime.tryParse(json['started_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      arrivesAt:
          DateTime.tryParse(json['arrives_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      speedTilesPerSecond:
          (json['speed_tiles_per_second'] as num?)?.toDouble() ?? 4,
    );
  }
}

class PlayerState {
  const PlayerState({
    required this.userId,
    required this.x,
    required this.y,
    required this.movement,
    required this.action,
    required this.updatedAt,
  });

  final String userId;
  final int x;
  final int y;
  final PlayerMovement? movement;
  final PlayerAction? action;
  final DateTime? updatedAt;

  factory PlayerState.fromJson(Map<String, dynamic> json) {
    final movement = json['movement'];
    final action = json['action'];
    return PlayerState(
      userId: json['user_id'] as String? ?? '',
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      movement:
          movement is Map<String, dynamic>
              ? PlayerMovement.fromJson(movement)
              : null,
      action:
          action is Map<String, dynamic> ? PlayerAction.fromJson(action) : null,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }

  PlayerState copyWith({PlayerMovement? movement, PlayerAction? action}) {
    return PlayerState(
      userId: userId,
      x: x,
      y: y,
      movement: movement ?? this.movement,
      action: action ?? this.action,
      updatedAt: updatedAt,
    );
  }
}

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
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
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
