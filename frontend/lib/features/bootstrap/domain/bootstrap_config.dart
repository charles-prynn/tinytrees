class BootstrapConfig {
  const BootstrapConfig({
    required this.apiVersion,
    required this.features,
    required this.serverTime,
  });

  final String apiVersion;
  final List<String> features;
  final DateTime serverTime;

  factory BootstrapConfig.fromJson(Map<String, dynamic> json) {
    final config = json['config'] as Map<String, dynamic>? ?? {};
    return BootstrapConfig(
      apiVersion: config['api_version'] as String? ?? 'v1',
      features:
          (config['features'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(),
      serverTime:
          DateTime.tryParse(json['server_time'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}
