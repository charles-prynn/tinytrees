part of '../tile_map_game.dart';

class EntityInteractionTarget {
  const EntityInteractionTarget({
    this.entityId = '',
    required this.tile,
    required this.facing,
  });

  final String entityId;
  final math.Point<int> tile;
  final PlayerFacing facing;
}
