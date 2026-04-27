import 'dart:ui';

class EntityFrame {
  const EntityFrame({
    required this.source,
    this.drawWidthTiles,
    this.drawHeightTiles,
    this.anchorXTiles,
    this.anchorYTiles,
    this.foregroundSplitY,
  });

  final Rect source;
  final double? drawWidthTiles;
  final double? drawHeightTiles;
  final double? anchorXTiles;
  final double? anchorYTiles;
  final double? foregroundSplitY;
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
    this.tintColor,
    required this.animations,
  });

  final String imageKey;
  final double drawWidthTiles;
  final double drawHeightTiles;
  final double anchorXTiles;
  final double anchorYTiles;
  final double? foregroundSplitY;
  final Color? tintColor;
  final Map<String, EntityAnimationDefinition> animations;

  EntityAnimationDefinition animationFor(String state) {
    return animations[state] ?? animations['idle'] ?? animations.values.first;
  }
}

EntityAnimationDefinition _treeIdleAnimation() {
  return EntityAnimationDefinition(
    frameDuration: const Duration(milliseconds: 120),
    frames: [
      for (var frame = 0; frame < 16; frame++)
        EntityFrame(
          source: Rect.fromLTWH((frame * 64 + 12).toDouble(), 0, 39, 64),
        ),
    ],
  );
}

const EntityAnimationDefinition _treeStumpAnimation = EntityAnimationDefinition(
  frameDuration: Duration.zero,
  frames: [
    EntityFrame(
      source: Rect.fromLTWH(12, 42, 39, 22),
      drawWidthTiles: 1.6,
      drawHeightTiles: 1.2,
      anchorXTiles: 0.8,
      anchorYTiles: 1.2,
    ),
  ],
);

EntityVisualDefinition _treeVisual({Color? tintColor}) {
  return EntityVisualDefinition(
    imageKey: 'animated_autumn_tree',
    drawWidthTiles: 2.4375,
    drawHeightTiles: 4,
    anchorXTiles: 1.21875,
    anchorYTiles: 4,
    foregroundSplitY: 48,
    tintColor: tintColor,
    animations: {'idle': _treeIdleAnimation(), 'depleted': _treeStumpAnimation},
  );
}

final Map<String, EntityVisualDefinition> entityVisualDefinitions = {
  'tree': _treeVisual(),
  'oak_tree': _treeVisual(tintColor: const Color(0xFFD7A45F)),
  'willow_tree': _treeVisual(tintColor: const Color(0xFF81C784)),
  'maple_tree': _treeVisual(tintColor: const Color(0xFFE67E45)),
  'yew_tree': _treeVisual(tintColor: const Color(0xFF4E7A4A)),
  'magic_tree': _treeVisual(tintColor: const Color(0xFF7CC7D9)),
};
