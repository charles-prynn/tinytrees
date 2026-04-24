import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.websocketBaseUrl,
    required this.environment,
    required this.debugFps,
  });

  final String apiBaseUrl;
  final String websocketBaseUrl;
  final String environment;
  final bool debugFps;

  factory AppConfig.fromEnvironment() {
    const apiBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    );
    const configuredWebsocketBaseUrl = String.fromEnvironment(
      'WEBSOCKET_BASE_URL',
      defaultValue: '',
    );

    return AppConfig(
      apiBaseUrl: apiBaseUrl,
      websocketBaseUrl:
          configuredWebsocketBaseUrl.isNotEmpty
              ? configuredWebsocketBaseUrl
              : _deriveWebSocketBaseURL(apiBaseUrl),
      environment: const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'development',
      ),
      debugFps: const bool.fromEnvironment('DEBUG_FPS'),
    );
  }

  static String _deriveWebSocketBaseURL(String apiBaseUrl) {
    final uri = Uri.parse(apiBaseUrl);
    final scheme =
        uri.scheme == 'https'
            ? 'wss'
            : uri.scheme == 'http'
            ? 'ws'
            : uri.scheme;
    return uri.replace(scheme: scheme).toString();
  }
}
