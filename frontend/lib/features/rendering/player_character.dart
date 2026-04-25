import 'dart:convert';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flutter/services.dart';

class PlayerCharacterLayer {
  const PlayerCharacterLayer({
    required this.name,
    required this.assetPath,
    required this.zPos,
    required this.image,
  });

  final String name;
  final String assetPath;
  final int zPos;
  final Image image;
}

class PlayerCharacterSheet {
  const PlayerCharacterSheet({required this.layers});

  final List<PlayerCharacterLayer> layers;

  static const frameSize = 64.0;

  static Future<PlayerCharacterSheet> load(Images images) async {
    final raw = await rootBundle.loadString(
      'assets/images/sprites/character/character.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final layerDefs = json['layers'] as List<dynamic>? ?? const [];
    final layers = <PlayerCharacterLayer>[];

    for (final entry in layerDefs) {
      final layer = entry as Map<String, dynamic>;
      final zPos = (layer['zPos'] as num?)?.toInt() ?? 0;
      final name = layer['name'] as String? ?? 'layer';
      final exportedFileName =
          '${zPos.toString().padLeft(3, '0')} ${_normalizeExportName(name)}.png';
      final assetPath = 'sprites/character/items/$exportedFileName';
      final image = await images.load(assetPath);
      layers.add(
        PlayerCharacterLayer(
          name: name,
          assetPath: assetPath,
          zPos: zPos,
          image: image,
        ),
      );
    }

    layers.sort((a, b) => a.zPos.compareTo(b.zPos));
    return PlayerCharacterSheet(layers: List.unmodifiable(layers));
  }

  Rect? sourceRectFor({
    required PlayerCharacterLayer layer,
    required PlayerCharacterAnimation animation,
    required PlayerCharacterDirection direction,
    required double elapsedSeconds,
  }) {
    final spec = _animationSpecFor(animation);
    final row = spec.rowOffset + spec.rowIndexFor(direction);
    final frameIndex =
        spec.frameCount <= 1
            ? 0
            : ((elapsedSeconds * spec.framesPerSecond).floor() %
                spec.frameCount);
    final left = frameIndex * frameSize;
    final top = row * frameSize;
    final rect = Rect.fromLTWH(left, top, frameSize, frameSize);
    final imageBounds = Rect.fromLTWH(
      0,
      0,
      layer.image.width.toDouble(),
      layer.image.height.toDouble(),
    );
    if (!imageBounds.contains(rect.topLeft) ||
        !imageBounds.contains(rect.bottomRight - const Offset(1, 1))) {
      return null;
    }
    return rect;
  }

  static _AnimationSpec _animationSpecFor(PlayerCharacterAnimation animation) {
    return switch (animation) {
      PlayerCharacterAnimation.idle => const _AnimationSpec(
        rowOffset: 8,
        frameCount: 1,
        framesPerSecond: 1,
        rightRowIndex: 3,
        leftRowIndex: 1,
        downRowIndex: 2,
        upRowIndex: 0,
      ),
      PlayerCharacterAnimation.walk => const _AnimationSpec(
        rowOffset: 8,
        frameCount: 9,
        framesPerSecond: 8,
        rightRowIndex: 3,
        leftRowIndex: 1,
        downRowIndex: 2,
        upRowIndex: 0,
      ),
      PlayerCharacterAnimation.slash => const _AnimationSpec(
        rowOffset: 12,
        frameCount: 6,
        framesPerSecond: 10,
        rightRowIndex: 3,
        leftRowIndex: 1,
        downRowIndex: 2,
        upRowIndex: 0,
      ),
    };
  }

  static String _normalizeExportName(String input) {
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      final char = String.fromCharCode(rune);
      final isAlphaNum =
          (rune >= 97 && rune <= 122) || (rune >= 48 && rune <= 57);
      buffer.write(isAlphaNum ? char : '_');
    }
    return buffer.toString();
  }
}

enum PlayerCharacterAnimation { idle, walk, slash }

enum PlayerCharacterDirection { right, left, down, up }

class _AnimationSpec {
  const _AnimationSpec({
    required this.rowOffset,
    required this.frameCount,
    required this.framesPerSecond,
    required this.rightRowIndex,
    required this.leftRowIndex,
    required this.downRowIndex,
    required this.upRowIndex,
  });

  final int rowOffset;
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
