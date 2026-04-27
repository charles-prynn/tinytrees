part of '../tile_map_game.dart';

class _XpDropEffect {
  const _XpDropEffect({
    required this.amount,
    required this.startedAtSeconds,
    required this.lane,
  });

  static const durationSeconds = 1.1;

  final int amount;
  final double startedAtSeconds;
  final int lane;

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
