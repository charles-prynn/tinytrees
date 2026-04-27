part of '../player_state.dart';

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
