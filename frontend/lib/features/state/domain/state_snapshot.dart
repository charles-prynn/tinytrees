class StateSnapshot {
  const StateSnapshot({
    required this.version,
    required this.metadata,
    required this.updatedAt,
  });

  final int version;
  final Map<String, dynamic> metadata;
  final DateTime? updatedAt;

  factory StateSnapshot.empty() {
    return const StateSnapshot(version: 1, metadata: {}, updatedAt: null);
  }

  factory StateSnapshot.fromJson(Map<String, dynamic> json) {
    final rawVersion = json['Version'] ?? json['version'] ?? 1;
    return StateSnapshot(
      version: rawVersion is num ? rawVersion.toInt() : 1,
      metadata: Map<String, dynamic>.from(
        (json['Metadata'] ?? json['metadata'] ?? const {}) as Map,
      ),
      updatedAt: DateTime.tryParse(
        (json['UpdatedAt'] ?? json['updated_at'] ?? '') as String,
      ),
    );
  }

  Map<String, dynamic> toSyncJson() {
    return {'version': version, 'metadata': metadata};
  }
}
