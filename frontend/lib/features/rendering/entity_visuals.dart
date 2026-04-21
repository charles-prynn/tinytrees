import 'dart:ui';

class EntityFrame {
  const EntityFrame({required this.source});

  final Rect source;
}

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

class EntityVisualDefinition {
  const EntityVisualDefinition({
    required this.imageKey,
    required this.drawWidthTiles,
    required this.drawHeightTiles,
    required this.anchorXTiles,
    required this.anchorYTiles,
    this.foregroundSplitY,
    required this.animations,
  });

  final String imageKey;
  final double drawWidthTiles;
  final double drawHeightTiles;
  final double anchorXTiles;
  final double anchorYTiles;
  final double? foregroundSplitY;
  final Map<String, EntityAnimationDefinition> animations;

  EntityAnimationDefinition animationFor(String state) {
    return animations[state] ?? animations['idle'] ?? animations.values.first;
  }
}

final Map<String, EntityVisualDefinition> entityVisualDefinitions = {
  'autumn_tree': EntityVisualDefinition(
    imageKey: 'animated_autumn_tree',
    drawWidthTiles: 2.4375,
    drawHeightTiles: 4,
    anchorXTiles: 1.21875,
    anchorYTiles: 4,
    foregroundSplitY: 48,
    animations: {
      'idle': EntityAnimationDefinition(
        frameDuration: Duration(milliseconds: 120),
        frames: [
          for (var frame = 0; frame < 16; frame++)
            EntityFrame(
              source: Rect.fromLTWH((frame * 64 + 12).toDouble(), 0, 39, 64),
            ),
        ],
      ),
    },
  ),
  'generic_resource': EntityVisualDefinition(
    imageKey: 'animated_autumn_tree',
    drawWidthTiles: 2.4375,
    drawHeightTiles: 4,
    anchorXTiles: 1.21875,
    anchorYTiles: 4,
    foregroundSplitY: 42,
    animations: {
      'idle': EntityAnimationDefinition(
        frameDuration: Duration(milliseconds: 120),
        frames: [
          for (var frame = 0; frame < 16; frame++)
            EntityFrame(
              source: Rect.fromLTWH((frame * 64 + 12).toDouble(), 0, 39, 64),
            ),
        ],
      ),
    },
  ),
};
