part of '../player_character.dart';

enum PlayerCharacterAnimation {
  idle('idle', 'Idle'),
  walk('walk', 'Walk'),
  slash('slash', 'Slash');

  const PlayerCharacterAnimation(this.folder, this.label);

  final String folder;
  final String label;

  bool supportedByLayer(Set<String> supportedAnimations) {
    return switch (this) {
      PlayerCharacterAnimation.idle => supportedAnimations.contains('idle'),
      PlayerCharacterAnimation.walk => supportedAnimations.contains('walk'),
      PlayerCharacterAnimation.slash => supportedAnimations.contains('slash'),
    };
  }
}
