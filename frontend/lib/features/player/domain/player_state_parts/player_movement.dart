part of '../player_state.dart';

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
