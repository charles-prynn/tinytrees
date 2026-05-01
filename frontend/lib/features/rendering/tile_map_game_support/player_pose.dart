part of '../tile_map_game.dart';

class _PlayerPose {
  const _PlayerPose({
    required this.position,
    required this.direction,
    required this.modelYaw,
    required this.isMoving,
  });

  final Offset position;
  final _PlayerDirection direction;
  final double modelYaw;
  final bool isMoving;
}
