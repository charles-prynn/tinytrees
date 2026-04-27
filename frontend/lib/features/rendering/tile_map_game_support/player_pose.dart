part of '../tile_map_game.dart';

class _PlayerPose {
  const _PlayerPose({
    required this.position,
    required this.direction,
    required this.isMoving,
  });

  final Offset position;
  final _PlayerDirection direction;
  final bool isMoving;
}
