import 'dart:async';
import 'dart:convert';

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
        throw const AppError('Realtime request timed out');
      },
    );
  }

  Future<void> close() async {
    final socket = _socket;
    final subscription = _subscription;
    _socket = null;
    _subscription = null;
    _connecting = null;
    _failPending(const AppError('Realtime connection closed'));
    await subscription?.cancel();
    await socket?.sink.close();
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

      final socket = WebSocketChannel.connect(
        Uri.parse(_webSocketURL(tokens.accessToken)),
      );
      _socket = socket;
      _connecting = null;
      _subscription = socket.stream.listen(
        _handleMessage,
        onError: (Object error) {
          _socket = null;
          _subscription = null;
          _failPending(AppError('Realtime connection failed', cause: error));
        },
        onDone: () {
          _socket = null;
          _subscription = null;
          _failPending(const AppError('Realtime connection closed'));
        },
        cancelOnError: true,
      );
      return socket;
    } catch (_) {
      _connecting = null;
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
      return;
    }

    final decoded = jsonDecode(event);
    if (decoded is! Map<String, dynamic>) {
      return;
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
      completer.completeError(
        AppError(
          error['message'] as String? ?? 'Realtime request failed',
          code: error['code'] as String?,
        ),
      );
      return;
    }

    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      completer.complete(data);
      return;
    }

    completer.completeError(
      const AppError('Realtime response did not include an object payload'),
    );
  }

  void _failPending(Object error) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    _pending.clear();
  }
}
