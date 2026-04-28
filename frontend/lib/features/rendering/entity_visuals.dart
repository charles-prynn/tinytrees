import 'dart:ui';

import '../shared/tree_resource_palette.dart';

part 'entity_visuals_parts/entity_frame.dart';
part 'entity_visuals_parts/entity_animation_definition.dart';
part 'entity_visuals_parts/entity_visual_definition.dart';

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
    imageKey: 'animated_tree',
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
  for (final entry in treeResourceTintColors.entries)
    entry.key: _treeVisual(tintColor: entry.value),
};
