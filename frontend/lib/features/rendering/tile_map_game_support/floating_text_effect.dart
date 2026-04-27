part of '../tile_map_game.dart';

class _FloatingTextEffect {
  const _FloatingTextEffect({
    required this.label,
    required this.x,
    required this.y,
    required this.startedAtSeconds,
    required this.lane,
    required this.color,
    required this.shadowColor,
  });

  static const durationSeconds = 1.1;

  final String label;
  final double x;
  final double y;
  final double startedAtSeconds;
  final int lane;
  final Color color;
  final Color shadowColor;

  double get horizontalDirection => lane.isEven ? -1 : 1;

  bool isComplete(double elapsedSeconds) {
    return elapsedSeconds - startedAtSeconds >= durationSeconds;
  }

  double progressAt(double elapsedSeconds) {
    return ((elapsedSeconds - startedAtSeconds) / durationSeconds)
        .clamp(0, 1)
        .toDouble();
  }
}
