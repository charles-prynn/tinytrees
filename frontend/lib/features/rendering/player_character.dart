import 'dart:convert';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flutter/services.dart';

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

class PlayerCharacterFrame {
  const PlayerCharacterFrame({required this.image, required this.sourceRect});

  final Image image;
  final Rect sourceRect;
}

class PlayerCharacterSlashTool {
  const PlayerCharacterSlashTool({
    required this.background,
    required this.foreground,
    required this.sparks,
  });

  final Image background;
  final Image foreground;
  final Image? sparks;
}

class PlayerCharacterSheet {
  const PlayerCharacterSheet({
    required this.layers,
    required this.axeSlashTool,
  });

  final List<PlayerCharacterLayer> layers;
  final PlayerCharacterSlashTool? axeSlashTool;

  bool get hasAxeSlashTool => axeSlashTool != null;

  static const frameSize = 64.0;
  static const oversizedFrameSize = 128.0;
  static const _animationFolders = <String>['idle', 'walk', 'slash'];

  static Future<PlayerCharacterSheet> load(Images images) async {
    final raw = await rootBundle.loadString(
      'assets/images/sprites/character/character.json',
    );
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final layerDefs = json['layers'] as List<dynamic>? ?? const [];
    final layers = <PlayerCharacterLayer>[];
    final axeSlashTool = await _loadAxeSlashTool(images);

    for (final entry in layerDefs) {
      final layer = entry as Map<String, dynamic>;
      final itemId = layer['itemId'] as String? ?? '';
      final zPos = (layer['zPos'] as num?)?.toInt() ?? 0;
      final name = layer['name'] as String? ?? 'layer';
      final supportedAnimations =
          (layer['supportedAnimations'] as List<dynamic>? ?? const [])
              .map((animation) => '$animation')
              .toSet();
      final exportedFileName =
          '${zPos.toString().padLeft(3, '0')}_${_normalizeExportName(name)}.png';
      final imagesByFolder = <String, Image>{};
      final candidateFolders = _candidateFoldersFor(supportedAnimations);

      for (final folder in candidateFolders) {
        final assetPath =
            'sprites/character/standard/$folder/$exportedFileName';
        try {
          imagesByFolder[folder] = await images.load(assetPath);
        } catch (_) {
          continue;
        }
      }

      if (imagesByFolder.isEmpty) {
        continue;
      }

      layers.add(
        PlayerCharacterLayer(
          name: name,
          itemId: itemId,
          zPos: zPos,
          supportedAnimations: supportedAnimations,
          imagesByFolder: Map.unmodifiable(imagesByFolder),
        ),
      );
    }

    layers.sort((a, b) => a.zPos.compareTo(b.zPos));
    return PlayerCharacterSheet(
      layers: List.unmodifiable(layers),
      axeSlashTool: axeSlashTool,
    );
  }

  static List<String> _candidateFoldersFor(Set<String> supportedAnimations) {
    final folders = <String>[];
    for (final animation in PlayerCharacterAnimation.values) {
      if (animation.supportedByLayer(supportedAnimations)) {
        folders.add(animation.folder);
      }
    }
    if (folders.isEmpty) {
      return _animationFolders;
    }
    return folders;
  }

  PlayerCharacterFrame? frameFor({
    required PlayerCharacterLayer layer,
    required PlayerCharacterAnimation animation,
    required PlayerCharacterDirection direction,
    required double elapsedSeconds,
  }) {
    final folder = _resolvedFolderForLayer(layer, animation);
    if (folder == null) {
      return null;
    }
    final image = layer.imagesByFolder[folder];
    if (image == null) {
      return null;
    }

    final spec = _animationSpecFor(folder);
    final row = spec.rowIndexFor(direction);
    final frameIndex = _frameIndexFor(
      folder: folder,
      requestedAnimation: animation,
      layer: layer,
      elapsedSeconds: elapsedSeconds,
      spec: spec,
    );
    final left = frameIndex * frameSize;
    final top = row * frameSize;
    final rect = Rect.fromLTWH(left, top, frameSize, frameSize);
    final imageBounds = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    if (!imageBounds.contains(rect.topLeft) ||
        !imageBounds.contains(rect.bottomRight - const Offset(1, 1))) {
      return null;
    }

    return PlayerCharacterFrame(image: image, sourceRect: rect);
  }

  int _frameIndexFor({
    required String folder,
    required PlayerCharacterAnimation requestedAnimation,
    required PlayerCharacterLayer layer,
    required double elapsedSeconds,
    required _AnimationSpec spec,
  }) {
    if (spec.frameCount <= 1) {
      return 0;
    }

    // Keep all layers on the same still pose while idle. Some layers only ship
    // a walk sheet, so animating idle selectively makes the character look
    // split between idle and walking.
    if (requestedAnimation == PlayerCharacterAnimation.idle) {
      return 0;
    }

    final useSmashSlashTiming =
        requestedAnimation == PlayerCharacterAnimation.slash &&
        axeSlashTool != null &&
        layer.itemId != 'tool_smash' &&
        folder == 'slash';
    if (useSmashSlashTiming) {
      return _smashSlashFrameIndex(elapsedSeconds);
    }

    return ((elapsedSeconds * spec.framesPerSecond).floor() % spec.frameCount);
  }

  PlayerCharacterFrame? axeSlashBackgroundFrame({
    required PlayerCharacterDirection direction,
    required double elapsedSeconds,
  }) {
    final tool = axeSlashTool;
    if (tool == null) {
      return null;
    }
    return _oversizedToolFrame(
      image: tool.background,
      direction: direction,
      elapsedSeconds: elapsedSeconds,
    );
  }

  PlayerCharacterFrame? axeSlashForegroundFrame({
    required PlayerCharacterDirection direction,
    required double elapsedSeconds,
  }) {
    final tool = axeSlashTool;
    if (tool == null) {
      return null;
    }
    return _oversizedToolFrame(
      image: tool.foreground,
      direction: direction,
      elapsedSeconds: elapsedSeconds,
    );
  }

  PlayerCharacterFrame? axeSlashSparksFrame({
    required PlayerCharacterDirection direction,
    required double elapsedSeconds,
  }) {
    final image = axeSlashTool?.sparks;
    if (image == null) {
      return null;
    }
    return _oversizedToolFrame(
      image: image,
      direction: direction,
      elapsedSeconds: elapsedSeconds,
    );
  }

  String? _resolvedFolderForLayer(
    PlayerCharacterLayer layer,
    PlayerCharacterAnimation requested,
  ) {
    if (requested == PlayerCharacterAnimation.slash &&
        layer.itemId == 'tool_smash' &&
        axeSlashTool != null) {
      return null;
    }

    final preferredFolders = switch (requested) {
      PlayerCharacterAnimation.idle => const ['idle'],
      PlayerCharacterAnimation.walk => const ['walk'],
      PlayerCharacterAnimation.slash =>
        axeSlashTool != null
            ? const ['slash', 'walk']
            : const ['slash', 'walk'],
    };

    for (final folder in preferredFolders) {
      if (layer.imagesByFolder.containsKey(folder)) {
        return folder;
      }
    }

    return layer.imagesByFolder.keys.first;
  }

  static Future<PlayerCharacterSlashTool?> _loadAxeSlashTool(
    Images images,
  ) async {
    try {
      final background = await images.load(
        'sprites/character/tools/slash/axe-bg.png',
      );
      final foreground = await images.load(
        'sprites/character/tools/slash/axe.png',
      );
      Image? sparks;
      try {
        sparks = await images.load(
          'sprites/character/tools/slash/axe-sparks.png',
        );
      } catch (_) {
        sparks = null;
      }
      return PlayerCharacterSlashTool(
        background: background,
        foreground: foreground,
        sparks: sparks,
      );
    } catch (_) {
      return null;
    }
  }

  static PlayerCharacterFrame? _oversizedToolFrame({
    required Image image,
    required PlayerCharacterDirection direction,
    required double elapsedSeconds,
  }) {
    final selectedFrame = _smashSlashFrameIndex(elapsedSeconds);

    final rect = Rect.fromLTWH(
      selectedFrame * oversizedFrameSize,
      _oversizedRowIndexFor(direction) * oversizedFrameSize,
      oversizedFrameSize,
      oversizedFrameSize,
    );
    final imageBounds = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    if (!imageBounds.contains(rect.topLeft) ||
        !imageBounds.contains(rect.bottomRight - const Offset(1, 1))) {
      return null;
    }
    return PlayerCharacterFrame(image: image, sourceRect: rect);
  }

  static int _oversizedRowIndexFor(PlayerCharacterDirection direction) {
    return switch (direction) {
      PlayerCharacterDirection.up => 0,
      PlayerCharacterDirection.left => 1,
      PlayerCharacterDirection.down => 2,
      PlayerCharacterDirection.right => 3,
    };
  }

  static int _smashSlashFrameIndex(double elapsedSeconds) {
    const frameOrder = [5, 4, 3, 1, 0];
    const frameDurationsSeconds = [0.1, 0.1, 0.05, 0.1, 0.3];
    const totalDurationSeconds = 0.65;

    final loopTime = elapsedSeconds % totalDurationSeconds;
    var elapsed = 0.0;
    var selectedFrame = frameOrder.last;
    for (var index = 0; index < frameOrder.length; index++) {
      elapsed += frameDurationsSeconds[index];
      if (loopTime < elapsed) {
        selectedFrame = frameOrder[index];
        break;
      }
    }
    return selectedFrame;
  }

  static _AnimationSpec _animationSpecFor(String folder) {
    return switch (folder) {
      'idle' => const _AnimationSpec(
        frameCount: 2,
        framesPerSecond: 2,
        rightRowIndex: 3,
        leftRowIndex: 1,
        downRowIndex: 2,
        upRowIndex: 0,
      ),
      'slash' => const _AnimationSpec(
        frameCount: 6,
        framesPerSecond: 10,
        rightRowIndex: 3,
        leftRowIndex: 1,
        downRowIndex: 2,
        upRowIndex: 0,
      ),
      'walk' => const _AnimationSpec(
        frameCount: 9,
        framesPerSecond: 8,
        rightRowIndex: 3,
        leftRowIndex: 1,
        downRowIndex: 2,
        upRowIndex: 0,
      ),
      _ => const _AnimationSpec(
        frameCount: 1,
        framesPerSecond: 1,
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

enum PlayerCharacterDirection { right, left, down, up }

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
