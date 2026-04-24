import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../errors/app_error.dart';
import '../storage/token_storage.dart';

final gameSocketProvider = Provider<GameSocket>((ref) {
  final socket = GameSocket(
    config: ref.watch(appConfigProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
  ref.onDispose(socket.close);
  return socket;
});

class GameSocket {
  GameSocket({required AppConfig config, required TokenStorage tokenStorage})
    : _config = config,
      _tokenStorage = tokenStorage;

  final AppConfig _config;
  final TokenStorage _tokenStorage;
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  final StreamController<GameSocketMessage> _events =
      StreamController<GameSocketMessage>.broadcast();

  WebSocketChannel? _socket;
  Future<WebSocketChannel>? _connecting;
  StreamSubscription? _subscription;
  int _nextID = 0;

  Future<Map<String, dynamic>> request(
    String type, {
    Map<String, dynamic>? payload,
  }) async {
    final socket = await _connect();
    final id = (++_nextID).toString();
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _debugLog('send', {
      'id': id,
      'type': type,
      if (payload != null) 'payload': payload,
    });

    socket.sink.add(
      jsonEncode({
        'id': id,
        'type': type,
        if (payload != null) 'payload': payload,
      }),
    );

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _pending.remove(id);
        _debugLog('timeout', {'id': id, 'type': type});
        throw const AppError('Realtime request timed out');
      },
    );
  }

  Future<void> ensureConnected() async {
    await request('ping');
  }

  Future<void> close() async {
    final socket = _socket;
    final subscription = _subscription;
    _socket = null;
    _subscription = null;
    _connecting = null;
    _failPending(const AppError('Realtime connection closed'));
    _debugLog('close');
    await subscription?.cancel();
    await socket?.sink.close();
    await _events.close();
  }

  Stream<Map<String, dynamic>> messagesOfType(String type) {
    return _events.stream
        .where((event) => event.type == type)
        .map((event) => event.data);
  }

  Future<WebSocketChannel> _connect() {
    final existing = _socket;
    if (existing != null) {
      return Future.value(existing);
    }

    final connecting = _connecting;
    if (connecting != null) {
      return connecting;
    }

    final next = _open();
    _connecting = next;
    return next;
  }

  Future<WebSocketChannel> _open() async {
    try {
      final tokens = await _tokenStorage.read();
      if (tokens == null) {
        throw const AppError(
          'Authentication is required',
          code: 'unauthorized',
        );
      }

      final uri = Uri.parse(_webSocketURL(tokens.accessToken));
      _debugLog('connect', {'url': _redactedURL(uri)});
      final socket = WebSocketChannel.connect(uri);
      _socket = socket;
      _connecting = null;
      _subscription = socket.stream.listen(
        _handleMessage,
        onError: (Object error) {
          _socket = null;
          _subscription = null;
          _debugLog('error', {'error': error.toString()});
          _failPending(AppError('Realtime connection failed', cause: error));
        },
        onDone: () {
          _socket = null;
          _subscription = null;
          _debugLog('done');
          _failPending(const AppError('Realtime connection closed'));
        },
        cancelOnError: true,
      );
      return socket;
    } catch (error) {
      _connecting = null;
      _debugLog('connect-failed', {'error': error.toString()});
      rethrow;
    }
  }

  String _webSocketURL(String accessToken) {
    final base = Uri.parse(_config.websocketBaseUrl);
    final scheme =
        base.scheme == 'https'
            ? 'wss'
            : base.scheme == 'http'
            ? 'ws'
            : base.scheme;
    final queryParameters = <String, String>{};
    if (kIsWeb) {
      queryParameters['access_token'] = accessToken;
    }
    return base
        .replace(
          scheme: scheme,
          path: '/v1/ws',
          queryParameters: queryParameters.isEmpty ? null : queryParameters,
        )
        .toString();
  }

  void _handleMessage(dynamic event) {
    if (event is! String) {
      _debugLog('unexpected-event', {
        'runtime_type': event.runtimeType.toString(),
      });
      return;
    }

    final decoded = jsonDecode(event);
    if (decoded is! Map<String, dynamic>) {
      _debugLog('unexpected-payload', {'payload': event});
      return;
    }

    _debugLog('receive', decoded);

    final type = decoded['type'] as String?;
    final data = decoded['data'];
    if (type != null && data is Map<String, dynamic>) {
      _events.add(GameSocketMessage(type: type, data: data));
    }

    final id = decoded['id'] as String?;
    if (id == null) {
      return;
    }

    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) {
      return;
    }

    final error = decoded['error'];
    if (error is Map<String, dynamic>) {
      _debugLog('request-error', {'id': id, 'error': error});
      completer.completeError(
        AppError(
          error['message'] as String? ?? 'Realtime request failed',
          code: error['code'] as String?,
        ),
      );
      return;
    }

    if (data is Map<String, dynamic>) {
      _debugLog('request-ok', {'id': id, 'data': data});
      completer.complete(data);
      return;
    }

    _debugLog('invalid-response', {'id': id, 'payload': decoded});
    completer.completeError(
      const AppError('Realtime response did not include an object payload'),
    );
  }

  void _failPending(Object error) {
    _debugLog('fail-pending', {
      'count': _pending.length,
      'error': error.toString(),
    });
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pending.clear();
  }

  void _debugLog(String event, [Map<String, Object?> details = const {}]) {
    if (!_config.debugFps) {
      return;
    }
    developer.log(
      jsonEncode({'event': event, if (details.isNotEmpty) 'details': details}),
      name: 'game_socket',
    );
  }

  String _redactedURL(Uri uri) {
    final queryParameters = Map<String, String>.from(uri.queryParameters);
    if (queryParameters.containsKey('access_token')) {
      queryParameters['access_token'] = '<redacted>';
    }
    return uri.replace(queryParameters: queryParameters).toString();
  }
}

class GameSocketMessage {
  const GameSocketMessage({required this.type, required this.data});

  final String type;
  final Map<String, dynamic> data;
}
