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
  TileMapRenderer? _renderer;

  @override
  Color backgroundColor() => const Color(0xFF10241D);

  Future<void> get assetsLoaded => _assetsLoaded.future;

  @override
  Future<void> onLoad() async {
    try {
      final tileset = await images.load('tiles/tile_map.png');
      final walkIcon = await images.load('sprites/walk_icon.png');
      final playerCharacter = await PlayerCharacterSheet.load(images);
      final entityImages = {
        'animated_autumn_tree': await images.load(
          'entities/animated_autumn_tree.png',
        ),
      };
      _renderer = TileMapRenderer(
        tileset: tileset,
        walkIcon: walkIcon,
        playerCharacter: playerCharacter,
        entityImages: entityImages,
        renderConfig: _renderConfig,
        showDebugLabels: _showCoordinateDebug,
      );
      await add(_renderer!);
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
      _renderer!.entities = _pendingEntities;
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
    _renderer?.entities = _pendingEntities;
  }

  void setPlayer(PlayerState player) {
    _pendingPlayer = player;
    _renderer?.player = player;
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

  @override
  void onPanUpdate(DragUpdateInfo info) {
    _renderer?.panBy(info.delta.global);
  }
}

class TileRenderConfig {
  const TileRenderConfig({this.usableColumns = 32, this.usableRows = 16});

  final int usableColumns;
  final int usableRows;

  double tileSizeFor(Vector2 canvasSize) {
    return math.min(canvasSize.x / usableColumns, canvasSize.y / usableRows);
  }
}

class TileMapRenderer extends Component with HasGameReference<TileMapGame> {
  TileMapRenderer({
    required Image tileset,
    required Image walkIcon,
    required PlayerCharacterSheet playerCharacter,
    required Map<String, Image> entityImages,
    required TileRenderConfig renderConfig,
    required bool showDebugLabels,
  }) : _tileset = tileset,
       _walkIcon = walkIcon,
       _playerCharacter = playerCharacter,
       _entityImages = entityImages,
       _renderConfig = renderConfig,
       _showDebugLabels = showDebugLabels;

  final Image _tileset;
  final Image _walkIcon;
  final PlayerCharacterSheet _playerCharacter;
  final Map<String, Image> _entityImages;
  final TileRenderConfig _renderConfig;
  final bool _showDebugLabels;
  static const _playerRenderSmoothingSeconds = 0.36;
  TileMap? tileMap;
  List<WorldEntity> entities = const [];
  final List<_WalkIconEffect> _walkIconEffects = [];
  Image? _mapLayerImage;
  Object? _mapLayerKey;
  bool _mapLayerBuildQueued = false;
  PlayerState? _player;
  _PlayerRenderMotion? _playerRenderMotion;
  _PlayerDirection _lastPlayerDirection = _PlayerDirection.front;
  PlayerCharacterAnimation? debugAnimationOverride;
  double _panX = 0;
  double _panY = 0;
  double _elapsedSeconds = 0;
  bool _needsCentering = true;
  Vector2? _lastGameSize;

  PlayerState? get player => _player;

  set player(PlayerState? value) {
    final previous = _player;
    final currentRenderPosition = _playerRenderPosition();
    _player = value;
    if (value == null) {
      _playerRenderMotion = null;
      return;
    }
    final target = Offset(value.renderX, value.renderY);
    if (previous == null || currentRenderPosition == null) {
      _playerRenderMotion = _PlayerRenderMotion.snap(target);
      return;
    }
    final delta = target - currentRenderPosition;
    _lastPlayerDirection = _directionForDelta(delta);
    if (delta.distance > 1.5) {
      _playerRenderMotion = _PlayerRenderMotion.snap(target);
      return;
    }
    _playerRenderMotion = _PlayerRenderMotion(
      from: currentRenderPosition,
      to: target,
      startedAtSeconds: _elapsedSeconds,
      endsAtSeconds: _elapsedSeconds + _playerRenderSmoothingSeconds,
    );
  }

  set currentMap(TileMap? value) {
    if (!identical(tileMap, value)) {
      tileMap = value;
      _queueMapLayerRebuild();
      _needsCentering = true;
    }
  }

  @override
  void onRemove() {
    _mapLayerImage?.dispose();
    _mapLayerImage = null;
    super.onRemove();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final previousSize = _lastGameSize;
    _lastGameSize = size.clone();

    if (previousSize == null) {
      _needsCentering = true;
      return;
    }

    final sizeChanged = previousSize.x != size.x || previousSize.y != size.y;
    if (!sizeChanged) {
      return;
    }

    final map = tileMap;
    if (map == null) {
      _needsCentering = true;
      return;
    }

    final tileSize = _renderConfig.tileSizeFor(size);
    _panX = _clampPanX(_panX, map, tileSize);
    _panY = _clampPanY(_panY, map, tileSize);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsedSeconds += dt;
    _walkIconEffects.removeWhere(
      (effect) => effect.isComplete(_elapsedSeconds),
    );
  }

  void panBy(Vector2 delta) {
    if (player != null) {
      return;
    }

    final map = tileMap;
    if (map == null || game.size.x <= 0 || game.size.y <= 0) {
      return;
    }
    final tileSize = _renderConfig.tileSizeFor(game.size);
    _panX = _clampPanX(_panX - delta.x, map, tileSize);
    _panY = _clampPanY(_panY - delta.y, map, tileSize);
    _needsCentering = false;
  }

  String? holdLabelAt(Vector2 screenPosition) {
    final entity = entityAt(screenPosition);
    if (entity != null) {
      if (entity.name.isNotEmpty) {
        return entity.name;
      }
      return entity.resourceKey.isEmpty ? 'Entity' : entity.resourceKey;
    }

    final tile = tileAt(screenPosition);
    if (tile == null) {
      return null;
    }
    return 'Walk here';
  }

  WorldEntity? entityAt(Vector2 screenPosition) {
    final mapPosition = _mapPositionAt(screenPosition);
    if (mapPosition == null) {
      return null;
    }

    for (final entity in entities.reversed) {
      final bounds = _entityHitBounds(entity);
      if (bounds.contains(mapPosition)) {
        return entity;
      }
    }
    return null;
  }

  math.Point<int>? tileAt(Vector2 screenPosition) {
    final map = tileMap;
    if (map == null || game.size.x <= 0 || game.size.y <= 0) {
      return null;
    }

    final tileSize = _renderConfig.tileSizeFor(game.size);
    final offset = _mapOffset(map, tileSize);
    final col = ((screenPosition.x - offset.dx) / tileSize).floor();
    final row = ((screenPosition.y - offset.dy) / tileSize).floor();
    if (col < 0 || row < 0 || col >= map.width || row >= map.height) {
      return null;
    }
    return math.Point(col, row);
  }

  Offset? _mapPositionAt(Vector2 screenPosition) {
    final map = tileMap;
    if (map == null || game.size.x <= 0 || game.size.y <= 0) {
      return null;
    }

    final tileSize = _renderConfig.tileSizeFor(game.size);
    final offset = _mapOffset(map, tileSize);
    final x = (screenPosition.x - offset.dx) / tileSize;
    final y = (screenPosition.y - offset.dy) / tileSize;
    if (x < 0 || y < 0 || x >= map.width || y >= map.height) {
      return null;
    }
    return Offset(x, y);
  }

  Rect _entityHitBounds(WorldEntity entity) {
    final visual = entityVisualDefinitions[entity.resourceKey];
    if (visual != null) {
      return Rect.fromLTWH(
        entity.x + 0.5 - visual.anchorXTiles,
        entity.y + 1 - visual.anchorYTiles,
        visual.drawWidthTiles,
        visual.drawHeightTiles,
      );
    }

    return Rect.fromLTWH(
      entity.x.toDouble(),
      entity.y.toDouble(),
      math.max(1, entity.width).toDouble(),
      math.max(1, entity.height).toDouble(),
    );
  }

  bool isWalkableTileAt(Vector2 screenPosition) {
    final map = tileMap;
    final tile = tileAt(screenPosition);
    if (map == null || tile == null) {
      return false;
    }
    if (map.tileAt(tile.x, tile.y) <= 0) {
      return false;
    }
    return !_isTileBlocked(tile);
  }

  EntityInteractionTarget? entityInteractionTargetAt(Vector2 screenPosition) {
    final entity = entityAt(screenPosition);
    if (entity == null) {
      return null;
    }

    final playerPosition = _playerPosition();
    final candidates = _interactionCandidates(entity);
    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final player = playerPosition;
      if (player == null) {
        return 0;
      }
      final aDistance = _tileDistanceSquared(a.tile, player);
      final bDistance = _tileDistanceSquared(b.tile, player);
      return aDistance.compareTo(bDistance);
    });

    final target = candidates.first;
    return EntityInteractionTarget(
      entityId: entity.id,
      tile: target.tile,
      facing: target.facing,
    );
  }

  void facePlayer(PlayerFacing facing) {
    _lastPlayerDirection = _PlayerDirection.fromFacing(facing);
  }

  void showWalkIconAt(math.Point<int> tile) {
    _walkIconEffects.add(
      _WalkIconEffect(x: tile.x, y: tile.y, startedAtSeconds: _elapsedSeconds),
    );
  }

  List<EntityInteractionTarget> _interactionCandidates(WorldEntity entity) {
    final bounds = _entityCollisionBounds(entity);
    final candidates = <EntityInteractionTarget>[];

    for (var y = bounds.top.toInt(); y < bounds.bottom.toInt(); y++) {
      candidates.add(
        EntityInteractionTarget(
          tile: math.Point(bounds.left.toInt() - 1, y),
          facing: PlayerFacing.right,
        ),
      );
      candidates.add(
        EntityInteractionTarget(
          tile: math.Point(bounds.right.toInt(), y),
          facing: PlayerFacing.left,
        ),
      );
    }

    for (var x = bounds.left.toInt(); x < bounds.right.toInt(); x++) {
      candidates.add(
        EntityInteractionTarget(
          tile: math.Point(x, bounds.top.toInt() - 1),
          facing: PlayerFacing.front,
        ),
      );
      candidates.add(
        EntityInteractionTarget(
          tile: math.Point(x, bounds.bottom.toInt()),
          facing: PlayerFacing.back,
        ),
      );
    }

    return candidates
        .where((candidate) => _isTileWalkable(candidate.tile))
        .toList();
  }

  double _tileDistanceSquared(math.Point<int> tile, Offset position) {
    final dx = tile.x + 0.5 - position.dx;
    final dy = tile.y + 0.5 - position.dy;
    return dx * dx + dy * dy;
  }

  bool _isTileWalkable(math.Point<int> tile) {
    final map = tileMap;
    if (map == null) {
      return false;
    }
    if (tile.x < 0 ||
        tile.y < 0 ||
        tile.x >= map.width ||
        tile.y >= map.height) {
      return false;
    }
    if (map.tileAt(tile.x, tile.y) <= 0) {
      return false;
    }
    return !_isTileBlocked(tile);
  }

  bool _isTileBlocked(math.Point<int> tile) {
    return entities.any(
      (entity) => _entityCollisionBounds(
        entity,
      ).contains(Offset(tile.x + 0.5, tile.y + 0.5)),
    );
  }

  Rect _entityCollisionBounds(WorldEntity entity) {
    return Rect.fromLTWH(
      entity.x.toDouble(),
      entity.y.toDouble(),
      math.max(1, entity.width).toDouble(),
      math.max(1, entity.height).toDouble(),
    );
  }

  @override
  void render(Canvas canvas) {
    final map = tileMap;
    if (map == null) {
      _drawLoading(canvas);
      return;
    }

    if (game.size.x <= 0 || game.size.y <= 0) {
      return;
    }

    final sourceTileSize = map.tileSize <= 0 ? 32 : map.tileSize;
    final drawTileSize = _renderConfig.tileSizeFor(game.size);
    final playerPose = _playerPose();
    final playerPosition = playerPose?.position;
    if (playerPosition != null) {
      _centerOnPlayer(map, drawTileSize, playerPosition);
      _needsCentering = false;
    } else if (_needsCentering) {
      _centerOnUsableArea(map, drawTileSize);
      _needsCentering = false;
    }
    _panX = _clampPanX(_panX, map, drawTileSize);
    _panY = _clampPanY(_panY, map, drawTileSize);

    final offset = _mapOffset(map, drawTileSize);

    final paint =
        Paint()
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = false;
    final entityBorderPaint =
        Paint()
          ..color = const Color(0xFFFFD54F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    final sourceColumns = math.max(1, _tileset.width ~/ sourceTileSize);
    _drawMapLayer(
      canvas: canvas,
      map: map,
      offset: offset,
      drawTileSize: drawTileSize,
      sourceTileSize: sourceTileSize,
      sourceColumns: sourceColumns,
      paint: paint,
    );
    if (_showDebugLabels) {
      _drawTileCoordinates(
        canvas: canvas,
        map: map,
        offset: offset,
        drawTileSize: drawTileSize,
      );
    }

    for (final entity in entities) {
      _drawEntity(
        canvas: canvas,
        entity: entity,
        layer: _EntityRenderLayer.background,
        offset: offset,
        drawTileSize: drawTileSize,
        sourceTileSize: sourceTileSize,
        sourceColumns: sourceColumns,
        paint: paint,
        borderPaint: entityBorderPaint,
      );
    }

    if (playerPose != null) {
      _drawPlayer(
        canvas: canvas,
        pose: playerPose,
        offset: offset,
        drawTileSize: drawTileSize,
        paint: paint,
      );
    }

    for (final entity in entities) {
      _drawEntity(
        canvas: canvas,
        entity: entity,
        layer: _EntityRenderLayer.foreground,
        offset: offset,
        drawTileSize: drawTileSize,
        sourceTileSize: sourceTileSize,
        sourceColumns: sourceColumns,
        paint: paint,
        borderPaint: entityBorderPaint,
      );
    }

    for (final effect in _walkIconEffects) {
      _drawWalkIconEffect(
        canvas: canvas,
        effect: effect,
        offset: offset,
        drawTileSize: drawTileSize,
        paint: paint,
      );
    }
  }

  void _drawPlayer({
    required Canvas canvas,
    required _PlayerPose pose,
    required Offset offset,
    required double drawTileSize,
    required Paint paint,
  }) {
    final animation =
        debugAnimationOverride ??
        (player?.action?.type == 'harvest'
            ? PlayerCharacterAnimation.slash
            : pose.isMoving
            ? PlayerCharacterAnimation.walk
            : PlayerCharacterAnimation.idle);
    final direction = switch (pose.direction) {
      _PlayerDirection.front => PlayerCharacterDirection.down,
      _PlayerDirection.left => PlayerCharacterDirection.left,
      _PlayerDirection.right => PlayerCharacterDirection.right,
      _PlayerDirection.back => PlayerCharacterDirection.up,
    };

    final drawWidth = drawTileSize * 2;
    final drawHeight = drawWidth;
    final footX = offset.dx + (pose.position.dx + 0.5) * drawTileSize;
    final footY = offset.dy + (pose.position.dy + 1) * drawTileSize;
    final destination = Rect.fromLTWH(
      footX - drawWidth / 2,
      footY - drawHeight,
      drawWidth,
      drawHeight,
    );
    final oversizedDestination = Rect.fromLTWH(
      footX - drawWidth,
      footY - drawHeight * 1.5,
      drawWidth * 2,
      drawHeight * 2,
    );
    final useOversizedAxeSlash =
        animation == PlayerCharacterAnimation.slash &&
        _playerCharacter.hasAxeSlashTool;
    if (useOversizedAxeSlash) {
      final toolBackground = _playerCharacter.axeSlashBackgroundFrame(
        direction: direction,
        elapsedSeconds: _elapsedSeconds,
      );
      if (toolBackground != null) {
        canvas.drawImageRect(
          toolBackground.image,
          toolBackground.sourceRect,
          oversizedDestination,
          paint,
        );
      }
    }
    final oversizedCharacterDestination = Rect.fromLTWH(
      oversizedDestination.left + drawWidth / 2,
      oversizedDestination.top + drawHeight / 2,
      drawWidth,
      drawHeight,
    );
    for (final layer in _playerCharacter.layers) {
      final frame = _playerCharacter.frameFor(
        layer: layer,
        animation: animation,
        direction: direction,
        elapsedSeconds: _elapsedSeconds,
      );
      if (frame == null) {
        continue;
      }
      canvas.drawImageRect(
        frame.image,
        frame.sourceRect,
        useOversizedAxeSlash ? oversizedCharacterDestination : destination,
        paint,
      );
    }
    if (useOversizedAxeSlash) {
      final toolForeground = _playerCharacter.axeSlashForegroundFrame(
        direction: direction,
        elapsedSeconds: _elapsedSeconds,
      );
      if (toolForeground != null) {
        canvas.drawImageRect(
          toolForeground.image,
          toolForeground.sourceRect,
          oversizedDestination,
          paint,
        );
      }
      final toolSparks = _playerCharacter.axeSlashSparksFrame(
        direction: direction,
        elapsedSeconds: _elapsedSeconds,
      );
      if (toolSparks != null) {
        canvas.drawImageRect(
          toolSparks.image,
          toolSparks.sourceRect,
          oversizedDestination,
          paint,
        );
      }
    }
  }

  void _drawMapLayer({
    required Canvas canvas,
    required TileMap map,
    required Offset offset,
    required double drawTileSize,
    required int sourceTileSize,
    required int sourceColumns,
    required Paint paint,
  }) {
    final cachedLayer = _mapLayerImage;
    if (cachedLayer != null && _mapLayerKey == map) {
      canvas.drawImageRect(
        cachedLayer,
        Rect.fromLTWH(
          0,
          0,
          cachedLayer.width.toDouble(),
          cachedLayer.height.toDouble(),
        ),
        Rect.fromLTWH(
          offset.dx,
          offset.dy,
          map.width * drawTileSize,
          map.height * drawTileSize,
        ),
        paint,
      );
      return;
    }

    _drawMapTiles(
      canvas: canvas,
      map: map,
      offset: offset,
      drawTileSize: drawTileSize,
      sourceTileSize: sourceTileSize,
      sourceColumns: sourceColumns,
      paint: paint,
    );
  }

  void _drawMapTiles({
    required Canvas canvas,
    required TileMap map,
    required Offset offset,
    required double drawTileSize,
    required int sourceTileSize,
    required int sourceColumns,
    required Paint paint,
  }) {
    for (var row = 0; row < map.height; row++) {
      for (var col = 0; col < map.width; col++) {
        final tileId = map.tileAt(col, row);
        if (tileId <= 0) {
          continue;
        }
        final source = _tileSource(tileId, sourceTileSize, sourceColumns);
        final destination = Rect.fromLTWH(
          offset.dx + col * drawTileSize,
          offset.dy + row * drawTileSize,
          drawTileSize,
          drawTileSize,
        );

        canvas.drawImageRect(_tileset, source, destination, paint);
      }
    }
  }

  void _drawTileCoordinates({
    required Canvas canvas,
    required TileMap map,
    required Offset offset,
    required double drawTileSize,
  }) {
    final textStyle = TextStyle(
      color: const Color(0xFFF2E5C9),
      fontSize: math.max(7, drawTileSize * 0.18),
      fontWeight: FontWeight.w700,
      shadows: const [
        Shadow(
          color: Color(0xCC000000),
          offset: Offset(0, 1),
          blurRadius: 1,
        ),
      ],
    );

    for (var row = 0; row < map.height; row++) {
      for (var col = 0; col < map.width; col++) {
        final left = offset.dx + col * drawTileSize;
        final top = offset.dy + row * drawTileSize;
        final rect = Rect.fromLTWH(left, top, drawTileSize, drawTileSize);
        if (!rect.overlaps(Offset.zero & Size(game.size.x, game.size.y))) {
          continue;
        }
        final painter = TextPainter(
          text: TextSpan(text: '$col,$row', style: textStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: drawTileSize - 4);
        painter.paint(canvas, Offset(left + 2, top + 2));
      }
    }
  }

  Rect _tileSource(int tileId, int sourceTileSize, int sourceColumns) {
    final sourceIndex = tileId - 1;
    return Rect.fromLTWH(
      ((sourceIndex % sourceColumns) * sourceTileSize).toDouble(),
      ((sourceIndex ~/ sourceColumns) * sourceTileSize).toDouble(),
      sourceTileSize.toDouble(),
      sourceTileSize.toDouble(),
    );
  }

  void _queueMapLayerRebuild() {
    if (_mapLayerBuildQueued) {
      return;
    }
    _mapLayerBuildQueued = true;
    unawaited(_rebuildMapLayer());
  }

  Future<void> _rebuildMapLayer() async {
    await Future<void>.delayed(Duration.zero);
    _mapLayerBuildQueued = false;

    final map = tileMap;
    if (map == null || map.width <= 0 || map.height <= 0) {
      final oldLayer = _mapLayerImage;
      _mapLayerImage = null;
      _mapLayerKey = null;
      oldLayer?.dispose();
      return;
    }

    final sourceTileSize = map.tileSize <= 0 ? 32 : map.tileSize;
    final sourceColumns = math.max(1, _tileset.width ~/ sourceTileSize);
    final imageWidth = map.width * sourceTileSize;
    final imageHeight = map.height * sourceTileSize;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint =
        Paint()
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = false;

    _drawMapTiles(
      canvas: canvas,
      map: map,
      offset: Offset.zero,
      drawTileSize: sourceTileSize.toDouble(),
      sourceTileSize: sourceTileSize,
      sourceColumns: sourceColumns,
      paint: paint,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(imageWidth, imageHeight);
    picture.dispose();

    if (!identical(tileMap, map)) {
      image.dispose();
      _queueMapLayerRebuild();
      return;
    }

    final oldLayer = _mapLayerImage;
    _mapLayerImage = image;
    _mapLayerKey = map;
    oldLayer?.dispose();
  }

  void _drawWalkIconEffect({
    required Canvas canvas,
    required _WalkIconEffect effect,
    required Offset offset,
    required double drawTileSize,
    required Paint paint,
  }) {
    final frame = effect.frameAt(_elapsedSeconds);
    final source = Rect.fromLTWH((frame * 32).toDouble(), 0, 32, 32);
    final destination = Rect.fromLTWH(
      offset.dx + effect.x * drawTileSize,
      offset.dy + effect.y * drawTileSize,
      drawTileSize,
      drawTileSize,
    );
    canvas.drawImageRect(_walkIcon, source, destination, paint);
  }

  void _drawEntity({
    required Canvas canvas,
    required WorldEntity entity,
    required _EntityRenderLayer layer,
    required Offset offset,
    required double drawTileSize,
    required int sourceTileSize,
    required int sourceColumns,
    required Paint paint,
    required Paint borderPaint,
  }) {
    final visual = entityVisualDefinitions[entity.resourceKey];
    if (visual != null) {
      final image = _entityImages[visual.imageKey];
      if (image == null) {
        return;
      }

      final animation = visual.animationFor(entity.state);
      final frame = animation.frameAt(
        Duration(milliseconds: (_elapsedSeconds * 1000).floor()),
      );
      final destinationBounds = Rect.fromLTWH(
        offset.dx + (entity.x + 0.5 - visual.anchorXTiles) * drawTileSize,
        offset.dy + (entity.y + 1 - visual.anchorYTiles) * drawTileSize,
        visual.drawWidthTiles * drawTileSize,
        visual.drawHeightTiles * drawTileSize,
      );
      _drawEntityVisualLayer(
        canvas: canvas,
        image: image,
        source: frame.source,
        destination: destinationBounds,
        splitY: visual.foregroundSplitY,
        layer: layer,
        paint: paint,
      );
      return;
    }

    if (layer != _EntityRenderLayer.foreground) {
      return;
    }

    final spriteGid = entity.spriteGid;
    if (spriteGid <= 0) {
      return;
    }
    final sourceIndex = spriteGid - 1;
    final source = Rect.fromLTWH(
      ((sourceIndex % sourceColumns) * sourceTileSize).toDouble(),
      ((sourceIndex ~/ sourceColumns) * sourceTileSize).toDouble(),
      sourceTileSize.toDouble(),
      sourceTileSize.toDouble(),
    );
    final destination = Rect.fromLTWH(
      offset.dx + entity.x * drawTileSize,
      offset.dy + entity.y * drawTileSize,
      math.max(1, entity.width) * drawTileSize,
      math.max(1, entity.height) * drawTileSize,
    );
    canvas.drawImageRect(_tileset, source, destination, paint);
    canvas.drawRect(destination.deflate(1), borderPaint);
  }

  void _drawEntityVisualLayer({
    required Canvas canvas,
    required Image image,
    required Rect source,
    required Rect destination,
    required double? splitY,
    required _EntityRenderLayer layer,
    required Paint paint,
  }) {
    if (splitY == null) {
      if (layer == _EntityRenderLayer.foreground) {
        canvas.drawImageRect(image, source, destination, paint);
      }
      return;
    }

    final clampedSplit = splitY.clamp(0, source.height).toDouble();
    if (layer == _EntityRenderLayer.background) {
      if (clampedSplit >= source.height) {
        return;
      }
      final sourcePart = Rect.fromLTWH(
        source.left,
        source.top + clampedSplit,
        source.width,
        source.height - clampedSplit,
      );
      final destinationPart = Rect.fromLTWH(
        destination.left,
        destination.top + destination.height * (clampedSplit / source.height),
        destination.width,
        destination.height * ((source.height - clampedSplit) / source.height),
      );
      canvas.drawImageRect(image, sourcePart, destinationPart, paint);
      return;
    }

    if (clampedSplit <= 0) {
      return;
    }
    final sourcePart = Rect.fromLTWH(
      source.left,
      source.top,
      source.width,
      clampedSplit,
    );
    final destinationPart = Rect.fromLTWH(
      destination.left,
      destination.top,
      destination.width,
      destination.height * (clampedSplit / source.height),
    );
    canvas.drawImageRect(image, sourcePart, destinationPart, paint);
  }

  Offset? _playerPosition() {
    return _playerPose()?.position;
  }

  Offset? _playerRenderPosition() {
    final motion = _playerRenderMotion;
    if (motion != null) {
      return motion.positionAt(_elapsedSeconds);
    }
    final current = _player;
    if (current == null) {
      return null;
    }
    return Offset(current.renderX, current.renderY);
  }

  _PlayerPose? _playerPose() {
    return _serverPlayerPose(DateTime.now().toUtc());
  }

  _PlayerPose? _serverPlayerPose(DateTime now) {
    final current = player;
    return _serverPlayerPoseFor(current, now);
  }

  _PlayerPose? _serverPlayerPoseFor(PlayerState? current, DateTime now) {
    if (current == null) {
      return null;
    }

    final harvestDirection = _harvestDirectionFor(current);
    if (harvestDirection != null) {
      _lastPlayerDirection = harvestDirection;
      final renderPosition =
          _playerRenderPosition() ?? Offset(current.renderX, current.renderY);
      return _PlayerPose(
        position: renderPosition,
        direction: harvestDirection,
        isMoving: false,
      );
    }

    final movement = current.movement;
    final renderPosition =
        _playerRenderPosition() ?? Offset(current.renderX, current.renderY);
    if (movement == null || movement.path.isEmpty) {
      final motion = _playerRenderMotion;
      return _PlayerPose(
        position: renderPosition,
        direction: _lastPlayerDirection,
        isMoving: motion?.isActiveAt(_elapsedSeconds) ?? false,
      );
    }
    final direction = _directionForDelta(
      Offset(
        (movement.targetX - current.x).toDouble(),
        (movement.targetY - current.y).toDouble(),
      ),
    );
    _lastPlayerDirection = direction;
    return _PlayerPose(
      position: renderPosition,
      direction: direction,
      isMoving: now.isBefore(movement.arrivesAt),
    );
  }

  _PlayerDirection? _harvestDirectionFor(PlayerState current) {
    final action = current.action;
    final entityId = action?.entityId;
    if (action?.type != 'harvest' || entityId == null || entityId.isEmpty) {
      return null;
    }
    final entity = entities.cast<WorldEntity?>().firstWhere(
      (candidate) => candidate?.id == entityId,
      orElse: () => null,
    );
    if (entity == null) {
      return null;
    }

    final bounds = _entityCollisionBounds(entity);
    final playerX = current.x.toDouble() + 0.5;
    final playerY = current.y.toDouble() + 0.5;

    if (playerX < bounds.left) {
      return _PlayerDirection.right;
    }
    if (playerX > bounds.right) {
      return _PlayerDirection.left;
    }
    if (playerY < bounds.top) {
      return _PlayerDirection.front;
    }
    if (playerY > bounds.bottom) {
      return _PlayerDirection.back;
    }
    return null;
  }

  _PlayerDirection _directionForDelta(Offset delta) {
    if (delta.dx.abs() >= delta.dy.abs() && delta.dx != 0) {
      return delta.dx > 0 ? _PlayerDirection.right : _PlayerDirection.left;
    }
    if (delta.dy != 0) {
      return delta.dy > 0 ? _PlayerDirection.front : _PlayerDirection.back;
    }
    return _lastPlayerDirection;
  }

  double _clampPanX(double panX, TileMap map, double tileSize) {
    final mapWidth = map.width * tileSize;
    final maxPanX = math.max(0, mapWidth - game.size.x);
    return panX.clamp(0, maxPanX).toDouble();
  }

  double _clampPanY(double panY, TileMap map, double tileSize) {
    final mapHeight = map.height * tileSize;
    final maxPanY = math.max(0, mapHeight - game.size.y);
    return panY.clamp(0, maxPanY).toDouble();
  }

  void _centerOnUsableArea(TileMap map, double tileSize) {
    final mapCenterX = map.width * tileSize / 2;
    final mapCenterY = map.height * tileSize / 2;
    _panX = _clampPanX(mapCenterX - game.size.x / 2, map, tileSize);
    _panY = _clampPanY(mapCenterY - game.size.y / 2, map, tileSize);
  }

  void _centerOnPlayer(TileMap map, double tileSize, Offset playerPosition) {
    final playerCenterX = (playerPosition.dx + 0.5) * tileSize;
    final playerCenterY = (playerPosition.dy + 0.5) * tileSize;
    _panX = _clampPanX(playerCenterX - game.size.x / 2, map, tileSize);
    _panY = _clampPanY(playerCenterY - game.size.y / 2, map, tileSize);
  }

  Offset _mapOffset(TileMap map, double tileSize) {
    final mapPixelWidth = map.width * tileSize;
    final horizontalInset = math.max(0, (game.size.x - mapPixelWidth) / 2);
    return Offset(horizontalInset - _panX, -_panY);
  }

  void _drawLoading(Canvas canvas) {
    final painter = TextPainter(
      text: const TextSpan(
        text: 'Loading map',
        style: TextStyle(color: Color(0xFFEAF3EF), fontSize: 20),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        (game.size.x - painter.width) / 2,
        (game.size.y - painter.height) / 2,
      ),
    );
  }
}

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

enum _EntityRenderLayer { background, foreground }

enum PlayerFacing { front, right, left, back }

class EntityInteractionTarget {
  const EntityInteractionTarget({
    this.entityId = '',
    required this.tile,
    required this.facing,
  });

  final String entityId;
  final math.Point<int> tile;
  final PlayerFacing facing;
}

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

class _PlayerRenderMotion {
  const _PlayerRenderMotion({
    required this.from,
    required this.to,
    required this.startedAtSeconds,
    required this.endsAtSeconds,
  });

  factory _PlayerRenderMotion.snap(Offset position) {
    return _PlayerRenderMotion(
      from: position,
      to: position,
      startedAtSeconds: 0,
      endsAtSeconds: 0,
    );
  }

  final Offset from;
  final Offset to;
  final double startedAtSeconds;
  final double endsAtSeconds;

  bool isActiveAt(double elapsedSeconds) {
    return endsAtSeconds > startedAtSeconds && elapsedSeconds < endsAtSeconds;
  }

  Offset positionAt(double elapsedSeconds) {
    if (endsAtSeconds <= startedAtSeconds) {
      return to;
    }
    final progress =
        ((elapsedSeconds - startedAtSeconds) / (endsAtSeconds - startedAtSeconds))
            .clamp(0, 1)
            .toDouble();
    final eased = progress * progress * (3 - 2 * progress);
    return Offset.lerp(from, to, eased) ?? to;
  }
}

class _WalkIconEffect {
  const _WalkIconEffect({
    required this.x,
    required this.y,
    required this.startedAtSeconds,
  });

  static const frameCount = 5;
  static const frameDurationSeconds = 0.08;

  final int x;
  final int y;
  final double startedAtSeconds;

  bool isComplete(double elapsedSeconds) {
    return elapsedSeconds - startedAtSeconds >=
        frameCount * frameDurationSeconds;
  }

  int frameAt(double elapsedSeconds) {
    final elapsed = math.max(0, elapsedSeconds - startedAtSeconds);
    return (elapsed ~/ frameDurationSeconds).clamp(0, frameCount - 1).toInt();
  }
}
