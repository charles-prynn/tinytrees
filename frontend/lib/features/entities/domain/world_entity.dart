class WorldEntity {
  const WorldEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.resourceKey,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.spriteGid,
    required this.state,
    required this.metadata,
  });

  final String id;
  final String name;
  final String type;
  final String resourceKey;
  final int x;
  final int y;
  final int width;
  final int height;
  final int spriteGid;
  final String state;
  final Map<String, dynamic> metadata;

  bool get isDepleted => state == 'depleted';
  bool get isBank => type == 'bank';

  factory WorldEntity.fromJson(Map<String, dynamic> json) {
    return WorldEntity(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Entity',
      type: json['type'] as String? ?? '',
      resourceKey: json['resource_key'] as String? ?? '',
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 1,
      height: (json['height'] as num?)?.toInt() ?? 1,
      spriteGid: (json['sprite_gid'] as num?)?.toInt() ?? 1,
      state: json['state'] as String? ?? '',
      metadata: Map<String, dynamic>.from(
        (json['metadata'] as Map?) ?? const {},
      ),
    );
  }
}
