import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart';

import '../entities/domain/world_entity.dart';
import '../map/domain/tile_map.dart';
import '../player/domain/player_state.dart';
import 'entity_visuals.dart';
import 'player_character.dart';

part 'tile_map_renderer.dart';
part 'tile_map_game_parts/tile_render_config.dart';
part 'tile_map_game_support/player_direction.dart';
part 'tile_map_game_support/entity_render_layer.dart';
part 'tile_map_game_support/player_facing.dart';
part 'tile_map_game_support/entity_interaction_target.dart';
part 'tile_map_game_support/player_pose.dart';
part 'tile_map_game_support/player_low_poly_renderer.dart';
part 'tile_map_game_support/player_render_motion.dart';
part 'tile_map_game_support/walk_icon_effect.dart';
part 'tile_map_game_support/xp_drop_effect.dart';
part 'tile_map_game_support/floating_text_effect.dart';

class TileMapGame extends FlameGame with PanDetector {
  TileMapGame({
    TileRenderConfig renderConfig = const TileRenderConfig(),
    bool showFps = false,
    bool showCoordinateDebug = false,
  }) : _renderConfig = renderConfig,
       _showFps = showFps,
       _showCoordinateDebug = showCoordinateDebug;

  final TileRenderConfig _renderConfig;
  final bool _showFps;
  final bool _showCoordinateDebug;
  final Completer<void> _assetsLoaded = Completer<void>();
  TileMap? _pendingMap;
  List<WorldEntity> _pendingEntities = const [];
  PlayerState? _pendingPlayer;
  bool _useLowPolyPlayer = false;
  TileMapRenderer? _renderer;

  @override
  Color backgroundColor() => const Color(0xFF10241D);

  Future<void> get assetsLoaded => _assetsLoaded.future;

  Future<void> warmUpInteractions() async {
    await assetsLoaded;
    await _renderer?.warmUpInteractions();
  }

  @override
  Future<void> onLoad() async {
    try {
      final tileset = await images.load('tiles/tile_map.png');
      final walkIcon = await images.load('sprites/walk_icon.png');
      final playerCharacter = await PlayerCharacterSheet.load(images);
      final entityImages = {
        'animated_tree': await images.load('entities/animated_tree.png'),
      };
      _renderer = TileMapRenderer(
        tileset: tileset,
        walkIcon: walkIcon,
        playerCharacter: playerCharacter,
        entityImages: entityImages,
        renderConfig: _renderConfig,
        showDebugLabels: _showCoordinateDebug,
      );
      _renderer!.useLowPolyPlayer = _useLowPolyPlayer;
      await add(_renderer!);
      await _renderer!.warmUpInteractions();
      if (_showFps) {
        await add(
          FpsTextComponent<TextPaint>(
            position: Vector2(12, 92),
            textRenderer: TextPaint(
              style: const TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 14,
                shadows: [
                  Shadow(
                    color: Color(0xCC000000),
                    offset: Offset(1, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final pending = _pendingMap;
      if (pending != null) {
        _renderer!.currentMap = pending;
      }
      _renderer!.setEntities(_pendingEntities);
      _renderer!.player = _pendingPlayer;
      if (!_assetsLoaded.isCompleted) {
        _assetsLoaded.complete();
      }
    } catch (error, stackTrace) {
      if (!_assetsLoaded.isCompleted) {
        _assetsLoaded.completeError(error, stackTrace);
      }
      rethrow;
    }
  }

  void setTileMap(TileMap tileMap) {
    _pendingMap = tileMap;
    _renderer?.currentMap = tileMap;
  }

  void setEntities(List<WorldEntity> entities) {
    _pendingEntities = List.unmodifiable(entities);
    _renderer?.setEntities(_pendingEntities);
  }

  void setPlayer(PlayerState player) {
    _pendingPlayer = player;
    _renderer?.player = player;
  }

  void showEntityMessage(
    String entityID,
    String label, {
    Color color = const Color(0xFFF28F7A),
  }) {
    _renderer?.showEntityMessage(entityID, label, color: color);
  }

  String? holdLabelAt(Offset localPosition) {
    return _renderer?.holdLabelAt(Vector2(localPosition.dx, localPosition.dy));
  }

  math.Point<int>? tileAtLocalPosition(Offset localPosition) {
    return _renderer?.tileAt(Vector2(localPosition.dx, localPosition.dy));
  }

  bool isWalkableTileAtLocalPosition(Offset localPosition) {
    return _renderer?.isWalkableTileAt(
          Vector2(localPosition.dx, localPosition.dy),
        ) ??
        false;
  }

  EntityInteractionTarget? entityInteractionTargetAtLocalPosition(
    Offset localPosition,
  ) {
    return _renderer?.entityInteractionTargetAt(
      Vector2(localPosition.dx, localPosition.dy),
    );
  }

  void showWalkIconAt(math.Point<int> tile) {
    _renderer?.showWalkIconAt(tile);
  }

  void facePlayer(PlayerFacing facing) {
    _renderer?.facePlayer(facing);
  }

  void setDebugAnimationOverride(PlayerCharacterAnimation? animation) {
    _renderer?.debugAnimationOverride = animation;
  }

  void togglePlayerRenderMode() {
    _useLowPolyPlayer = !_useLowPolyPlayer;
    _renderer?.useLowPolyPlayer = _useLowPolyPlayer;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    _renderer?.panBy(info.delta.global);
  }
}
