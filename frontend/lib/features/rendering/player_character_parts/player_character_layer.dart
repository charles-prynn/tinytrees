part of '../player_character.dart';

class PlayerCharacterLayer {
  const PlayerCharacterLayer({
    required this.name,
    required this.itemId,
    required this.zPos,
    required this.supportedAnimations,
    required this.imagesByFolder,
  });

  final String name;
  final String itemId;
  final int zPos;
  final Set<String> supportedAnimations;
  final Map<String, Image> imagesByFolder;
}
