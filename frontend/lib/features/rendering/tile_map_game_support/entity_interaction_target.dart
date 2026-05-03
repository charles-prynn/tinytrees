part of '../tile_map_game.dart';

enum EntityInteractionKind { harvest, bank }

class EntityInteractionTarget {
  const EntityInteractionTarget({
    this.entityId = '',
    required this.kind,
    required this.tile,
    required this.facing,
  });

  final String entityId;
  final EntityInteractionKind kind;
  final math.Point<int> tile;
  final PlayerFacing facing;
}
