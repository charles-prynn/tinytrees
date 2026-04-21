class TileMap {
  const TileMap({
    required this.width,
    required this.height,
    required this.tileSize,
    required this.tiles,
    required this.updatedAt,
  });

  final int width;
  final int height;
  final int tileSize;
  final List<int> tiles;
  final DateTime? updatedAt;

  factory TileMap.fromJson(Map<String, dynamic> json) {
    final layers = json['layers'] as List<dynamic>? ?? const [];
    final firstTileLayer = layers.cast<Map<String, dynamic>?>().firstWhere(
      (layer) => layer?['type'] == 'tilelayer',
      orElse: () => null,
    );
    final rawTiles =
        json['tiles'] as List<dynamic>? ??
        firstTileLayer?['data'] as List<dynamic>? ??
        const [];

    return TileMap(
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      tileSize:
          (json['tile_size'] as num?)?.toInt() ??
          (json['tilewidth'] as num?)?.toInt() ??
          32,
      tiles: rawTiles.map((value) => (value as num).toInt()).toList(),
      updatedAt: DateTime.tryParse(
        json['updated_at'] as String? ??
            _propertyValue(json, 'updated_at') as String? ??
            '',
      ),
    );
  }

  static Object? _propertyValue(Map<String, dynamic> json, String name) {
    final properties = json['properties'] as List<dynamic>? ?? const [];
    for (final property in properties) {
      final map = property as Map<String, dynamic>;
      if (map['name'] == name) return map['value'];
    }
    return null;
  }

  int tileAt(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return 0;
    final index = y * width + x;
    if (index < 0 || index >= tiles.length) return 0;
    return tiles[index];
  }
}
