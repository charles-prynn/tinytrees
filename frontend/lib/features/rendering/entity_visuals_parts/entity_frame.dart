part of '../entity_visuals.dart';

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
