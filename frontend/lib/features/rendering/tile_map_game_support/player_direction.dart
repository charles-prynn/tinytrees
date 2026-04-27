part of '../tile_map_game.dart';

enum _PlayerDirection {
  front(0),
  right(1),
  left(2),
  back(3);

  const _PlayerDirection(this.row);

  final int row;

  factory _PlayerDirection.fromFacing(PlayerFacing facing) {
    return switch (facing) {
      PlayerFacing.front => _PlayerDirection.front,
      PlayerFacing.right => _PlayerDirection.right,
      PlayerFacing.left => _PlayerDirection.left,
      PlayerFacing.back => _PlayerDirection.back,
    };
  }
}
