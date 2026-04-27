part of '../tile_map_game.dart';

class _WalkIconEffect {
  const _WalkIconEffect({
    required this.x,
    required this.y,
    required this.startedAtSeconds,
  });

  static const frameCount = 5;
  static const frameDurationSeconds = 0.08;

  final int x;
  final int y;
  final double startedAtSeconds;

  bool isComplete(double elapsedSeconds) {
    return elapsedSeconds - startedAtSeconds >=
        frameCount * frameDurationSeconds;
  }

  int frameAt(double elapsedSeconds) {
    final elapsed = math.max(0, elapsedSeconds - startedAtSeconds);
    return (elapsed ~/ frameDurationSeconds).clamp(0, frameCount - 1).toInt();
  }
}
