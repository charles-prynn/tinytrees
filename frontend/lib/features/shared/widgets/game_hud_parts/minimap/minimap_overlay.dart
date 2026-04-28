part of '../../game_hud.dart';

class MinimapOverlay extends ConsumerStatefulWidget {
  const MinimapOverlay({super.key});

  static const double _panelWidth = 156;
  static const double _panelHeight = 156;
  static const double _mapInset = 10;

  @override
  ConsumerState<MinimapOverlay> createState() => _MinimapOverlayState();
}

class _MinimapOverlayState extends ConsumerState<MinimapOverlay> {
  ui.Image? _mapImage;
  TileMap? _mapImageSource;
  Object? _mapBuildToken;

  @override
  void dispose() {
    _disposeMapImage();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final map = ref.watch(mapControllerProvider).asData?.value;
    final player = ref.watch(playerControllerProvider).asData?.value;
    final entities = ref.watch(worldEntitiesProvider).asData?.value ?? const [];

    if (map == null || player == null) {
      return const SizedBox.shrink();
    }

    if (!identical(_mapImageSource, map)) {
      _queueMapImageBuild(map);
    }

    return SizedBox(
      width: MinimapOverlay._panelWidth,
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2419),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xAA7C6B48), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: SizedBox(
              width: MinimapOverlay._panelWidth - 12,
              height: MinimapOverlay._panelHeight - 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x44221810),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: const Color(0x665E5138),
                    width: 1.1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 0,
                      offset: Offset(1, 1),
                    ),
                    BoxShadow(
                      color: Color(0x226D6246),
                      blurRadius: 0,
                      offset: Offset(-1, -1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x22110D08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0x444D422F),
                        width: 0.9,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(MinimapOverlay._mapInset),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _MinimapPainter(
                            map: map,
                            mapImage: _mapImage,
                            player: player,
                            entities: entities,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _queueMapImageBuild(TileMap map) {
    _mapImageSource = map;
    final token = Object();
    _mapBuildToken = token;
    Future<void>(() async {
      final image = await _buildMapImage(map);
      if (!mounted || !identical(_mapBuildToken, token)) {
        image.dispose();
        return;
      }
      final previous = _mapImage;
      setState(() {
        _mapImage = image;
      });
      previous?.dispose();
    });
  }

  Future<ui.Image> _buildMapImage(TileMap map) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..style = PaintingStyle.fill;

    for (var y = 0; y < map.height; y++) {
      for (var x = 0; x < map.width; x++) {
        final tileId = map.tileAt(x, y);
        paint.color =
            tileId > 0 ? const Color(0xFF355846) : const Color(0xFF18211D);
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(map.width, map.height);
    picture.dispose();
    return image;
  }

  void _disposeMapImage() {
    _mapImage?.dispose();
    _mapImage = null;
    _mapImageSource = null;
    _mapBuildToken = null;
  }
}

class _MinimapPainter extends CustomPainter {
  const _MinimapPainter({
    required this.map,
    required this.mapImage,
    required this.player,
    required this.entities,
  });

  final TileMap map;
  final ui.Image? mapImage;
  final PlayerState player;
  final List<WorldEntity> entities;
  static const double _zoomFactor = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final contentRect = Offset.zero & size;
    canvas.drawRect(contentRect, Paint()..color = const Color(0xFF10241D));
    final viewport = _viewportRect(contentRect);
    _drawMapImage(canvas, contentRect, viewport);
    _drawEntities(canvas, contentRect, viewport);
    _drawPlayer(canvas, contentRect, viewport);
    canvas.drawRect(
      contentRect.deflate(1),
      Paint()
        ..color = const Color(0x66F5E3B0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  Rect _viewportRect(Rect destinationRect) {
    final visibleWidth = map.width / _zoomFactor;
    final visibleHeight = map.height / _zoomFactor;
    final destinationAspectRatio =
        destinationRect.width / destinationRect.height;
    var viewportWidth = visibleWidth;
    var viewportHeight = visibleHeight;

    if (viewportWidth / viewportHeight > destinationAspectRatio) {
      viewportHeight = viewportWidth / destinationAspectRatio;
    } else {
      viewportWidth = viewportHeight * destinationAspectRatio;
    }

    viewportWidth = math.min(viewportWidth, map.width.toDouble());
    viewportHeight = math.min(viewportHeight, map.height.toDouble());

    final playerCenterX = player.renderX + 0.5;
    final playerCenterY = player.renderY + 0.5;
    final maxLeft = math.max(0.0, map.width - viewportWidth);
    final maxTop = math.max(0.0, map.height - viewportHeight);
    final left = (playerCenterX - viewportWidth / 2).clamp(0.0, maxLeft);
    final top = (playerCenterY - viewportHeight / 2).clamp(0.0, maxTop);

    return Rect.fromLTWH(left, top, viewportWidth, viewportHeight);
  }

  void _drawMapImage(Canvas canvas, Rect rect, Rect viewport) {
    final image = mapImage;
    if (image == null) {
      canvas.drawRect(rect, Paint()..color = const Color(0xFF21372D));
      return;
    }
    canvas.drawImageRect(
      image,
      viewport,
      rect,
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
  }

  void _drawEntities(Canvas canvas, Rect rect, Rect viewport) {
    final entityPaint = Paint()..style = PaintingStyle.fill;
    final tileWidth = rect.width / viewport.width;
    final tileHeight = rect.height / viewport.height;
    final dotRadius = math.max(1.2, math.min(tileWidth, tileHeight) * 0.28);

    for (final entity in entities) {
      if (entity.isDepleted) {
        continue;
      }
      final entityCenterX = entity.x + entity.width / 2;
      final entityCenterY = entity.y + entity.height / 2;
      if (!viewport.inflate(1).contains(Offset(entityCenterX, entityCenterY))) {
        continue;
      }
      entityPaint.color =
          entity.type == 'resource'
              ? const Color(0xFF89C36B)
              : const Color(0xFFD7B56D);
      canvas.drawCircle(
        Offset(
          rect.left + (entityCenterX - viewport.left) * tileWidth,
          rect.top + (entityCenterY - viewport.top) * tileHeight,
        ),
        dotRadius,
        entityPaint,
      );
    }
  }

  void _drawPlayer(Canvas canvas, Rect rect, Rect viewport) {
    final tileWidth = rect.width / viewport.width;
    final tileHeight = rect.height / viewport.height;
    final position = Offset(
      rect.left + (player.renderX + 0.5 - viewport.left) * tileWidth,
      rect.top + (player.renderY + 0.5 - viewport.top) * tileHeight,
    );

    canvas.drawCircle(
      position,
      math.max(2.5, math.min(tileWidth, tileHeight) * 0.5),
      Paint()..color = const Color(0xFFF7F2D0),
    );
    canvas.drawCircle(
      position,
      math.max(4, math.min(tileWidth, tileHeight) * 0.75),
      Paint()
        ..color = const Color(0xAA5C2E13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) {
    return oldDelegate.map != map ||
        oldDelegate.mapImage != mapImage ||
        oldDelegate.player != player ||
        oldDelegate.entities != entities;
  }
}
