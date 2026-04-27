part of '../entity_visuals.dart';

class EntityAnimationDefinition {
  const EntityAnimationDefinition({
    required this.frames,
    required this.frameDuration,
    this.loop = true,
  });

  final List<EntityFrame> frames;
  final Duration frameDuration;
  final bool loop;

  EntityFrame frameAt(Duration elapsed) {
    if (frames.length == 1) {
      return frames.first;
    }

    final frameDurationMs = frameDuration.inMilliseconds;
    if (frameDurationMs <= 0) {
      return frames.first;
    }

    final rawIndex = elapsed.inMilliseconds ~/ frameDurationMs;
    final frameIndex =
        loop ? rawIndex % frames.length : rawIndex.clamp(0, frames.length - 1);
    return frames[frameIndex];
  }
}
