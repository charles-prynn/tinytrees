part of '../entity_visuals.dart';

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
