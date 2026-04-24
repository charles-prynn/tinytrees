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
    required this.skills,
    required this.updatedAt,
  });

  final String userId;
  final int x;
  final int y;
  final PlayerMovement? movement;
  final PlayerAction? action;
  final List<PlayerSkill> skills;
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
      skills:
          (json['skills'] as List<dynamic>? ?? const [])
              .map(
                (skill) => PlayerSkill.fromJson(skill as Map<String, dynamic>),
              )
              .toList(),
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }

  PlayerState copyWith({
    int? x,
    int? y,
    PlayerMovement? movement,
    bool clearMovement = false,
    PlayerAction? action,
    bool clearAction = false,
    List<PlayerSkill>? skills,
    DateTime? updatedAt,
  }) {
    return PlayerState(
      userId: userId,
      x: x ?? this.x,
      y: y ?? this.y,
      movement: clearMovement ? null : (movement ?? this.movement),
      action: clearAction ? null : (action ?? this.action),
      skills: skills ?? this.skills,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  PlayerSkill? skillByKey(String skillKey) {
    for (final skill in skills) {
      if (skill.skillKey == skillKey) {
        return skill;
      }
    }
    return null;
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

class PlayerSkill {
  const PlayerSkill({
    required this.skillKey,
    required this.xp,
    required this.level,
    required this.updatedAt,
  });

  final String skillKey;
  final int xp;
  final int level;
  final DateTime? updatedAt;

  factory PlayerSkill.fromJson(Map<String, dynamic> json) {
    return PlayerSkill(
      skillKey: json['skill_key'] as String? ?? '',
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    );
  }

  int get nextLevel => level + 1;

  int get currentLevelXP => xpRequiredForLevel(level);

  int get nextLevelXP => xpRequiredForLevel(nextLevel);

  double get progressToNextLevel {
    final span = nextLevelXP - currentLevelXP;
    if (span <= 0) {
      return 1;
    }
    final earned = (xp - currentLevelXP).clamp(0, span);
    return earned / span;
  }
}

int xpRequiredForLevel(int level) {
  if (level <= 1) {
    return 0;
  }
  return level * level * 100 - 100;
}
