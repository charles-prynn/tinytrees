part of '../player_character.dart';

class _AnimationSpec {
  const _AnimationSpec({
    required this.frameCount,
    required this.framesPerSecond,
    required this.rightRowIndex,
    required this.leftRowIndex,
    required this.downRowIndex,
    required this.upRowIndex,
  });

  final int frameCount;
  final double framesPerSecond;
  final int rightRowIndex;
  final int leftRowIndex;
  final int downRowIndex;
  final int upRowIndex;

  int rowIndexFor(PlayerCharacterDirection direction) {
    return switch (direction) {
      PlayerCharacterDirection.right => rightRowIndex,
      PlayerCharacterDirection.left => leftRowIndex,
      PlayerCharacterDirection.down => downRowIndex,
      PlayerCharacterDirection.up => upRowIndex,
    };
  }
}
