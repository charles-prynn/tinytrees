part of '../tile_map_game.dart';

class TileRenderConfig {
  const TileRenderConfig({this.usableColumns = 32, this.usableRows = 16});

  final int usableColumns;
  final int usableRows;

  double tileSizeFor(Vector2 canvasSize) {
    return math.min(canvasSize.x / usableColumns, canvasSize.y / usableRows);
  }
}
