import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../auth/token_refresher.dart';
import '../config/app_config.dart';
import '../errors/app_error.dart';
import '../storage/token_storage.dart';

part 'game_socket_parts/game_socket_connection_state.dart';
part 'game_socket_parts/game_socket_message.dart';

final gameSocketProvider = Provider<GameSocket>((ref) {
  final socket = GameSocket(
    config: ref.watch(appConfigProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
    tokenRefresher: ref.watch(tokenRefresherProvider),
  );
  ref.onDispose(socket.close);
  return socket;
});

final gameSocketConnectionProvider = StreamProvider<GameSocketConnectionState>((
  ref,
) {
  final socket = ref.watch(gameSocketProvider);
  return socket.connectionStates;
});

class GameSocket {
  GameSocket({
    required AppConfig config,
    required TokenStorage tokenStorage,
    required TokenRefresher tokenRefresher,
  }) : _config = config,
       _tokenStorage = tokenStorage,
       _tokenRefresher = tokenRefresher;

  final AppConfig _config;
  final TokenStorage _tokenStorage;
  final TokenRefresher _tokenRefresher;
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  final StreamController<GameSocketMessage> _events =
      StreamController<GameSocketMessage>.broadcast();
  final StreamController<GameSocketConnectionState> _connectionEvents =
      StreamController<GameSocketConnectionState>.broadcast();

  WebSocketChannel? _socket;
  Future<WebSocketChannel>? _connecting;
  StreamSubscription? _subscription;
  Future<void>? _reconnectLoop;
  GameSocketConnectionState _connectionState =
      GameSocketConnectionState.disconnected;
  bool _disposed = false;
  int _reconnectAttempt = 0;
  int _nextID = 0;

  Stream<GameSocketConnectionState> get connectionStates async* {
    yield _connectionState;
    yield* _connectionEvents.stream;
  }

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
    _disposed = true;
    final socket = _socket;
    final subscription = _subscription;
    _socket = null;
    _subscription = null;
    _connecting = null;
    _updateConnectionState(GameSocketConnectionState.disconnected);
    _failPending(const AppError('Realtime connection closed'));
    _debugLog('close');
    await subscription?.cancel();
    await socket?.sink.close();
    await _connectionEvents.close();
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

    _updateConnectionState(
      _reconnectAttempt > 0 ||
              _connectionState == GameSocketConnectionState.reconnecting
          ? GameSocketConnectionState.reconnecting
          : GameSocketConnectionState.connecting,
    );
    final next = _open();
    _connecting = next;
    return next;
  }

  Future<WebSocketChannel> _open() async {
    try {
      final tokens = await _readTokensForSocket();
      if (tokens == null) {
        throw const AppError(
          'Authentication is required',
          code: 'unauthorized',
        );
      }

      final uri = Uri.parse(_webSocketURL(tokens.accessToken));
      _debugLog('connect', {'url': _redactedURL(uri)});
      final shouldResync = _reconnectAttempt > 0;
      final socket = WebSocketChannel.connect(uri);
      _socket = socket;
      _connecting = null;
      _reconnectAttempt = 0;
      _updateConnectionState(GameSocketConnectionState.connected);
      _subscription = socket.stream.listen(
        _handleMessage,
        onError: (Object error) {
          _debugLog('error', {'error': error.toString()});
          _handleDisconnect(
            AppError('Realtime connection failed', cause: error),
          );
        },
        onDone: () {
          _debugLog('done');
          _handleDisconnect(const AppError('Realtime connection closed'));
        },
        cancelOnError: true,
      );
      if (shouldResync) {
        unawaited(_recoverState());
      }
      return socket;
    } catch (error) {
      _connecting = null;
      _debugLog('connect-failed', {'error': error.toString()});
      rethrow;
    }
  }

  Future<TokenPair?> _readTokensForSocket() async {
    final tokens = await _tokenStorage.read();
    if (tokens == null) {
      return null;
    }

    if (_reconnectAttempt <= 0) {
      return tokens;
    }

    final refreshed = await _tokenRefresher.refreshTokens();
    return refreshed ?? tokens;
  }

  String _webSocketURL(String accessToken) {
    final base = Uri.parse(_config.websocketBaseUrl);
    final scheme =
        base.scheme == 'https'
            ? 'wss'
            : base.scheme == 'http'
            ? 'ws'
            : base.scheme;
    final queryParameters = Map<String, String>.from(base.queryParameters);
    queryParameters['access_token'] = accessToken;
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

  void _handleDisconnect(Object error) {
    _socket = null;
    _subscription = null;
    _connecting = null;
    _failPending(error);
    if (_disposed) {
      return;
    }
    _updateConnectionState(GameSocketConnectionState.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectLoop != null || _disposed) {
      return;
    }
    _reconnectLoop = _runReconnectLoop();
  }

  Future<void> _runReconnectLoop() async {
    try {
      while (!_disposed && _socket == null) {
        final attempt = ++_reconnectAttempt;
        final delay = _reconnectDelay(attempt);
        _debugLog('reconnect-wait', {
          'attempt': attempt,
          'delay_ms': delay.inMilliseconds,
        });
        await Future<void>.delayed(delay);
        if (_disposed || _socket != null) {
          return;
        }
        try {
          await _connect();
          return;
        } catch (error) {
          _debugLog('reconnect-failed', {
            'attempt': attempt,
            'error': error.toString(),
          });
          if (_isUnauthorized(error)) {
            _updateConnectionState(GameSocketConnectionState.disconnected);
            return;
          }
        }
      }
    } finally {
      _reconnectLoop = null;
    }
  }

  Duration _reconnectDelay(int attempt) {
    const delays = [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 30),
    ];
    return delays[(attempt - 1).clamp(0, delays.length - 1)];
  }

  Future<void> _recoverState() async {
    try {
      await request('ping');
      await request('player.get');
      await request('entities.get');
      await request('inventory.get');
      await request('bank.get');
      _debugLog('resync-ok');
    } catch (error) {
      _debugLog('resync-failed', {'error': error.toString()});
    }
  }

  bool _isUnauthorized(Object error) {
    if (error is AppError && error.code == 'unauthorized') {
      return true;
    }
    if (error is DioException && error.response?.statusCode == 401) {
      return true;
    }
    final message = error.toString();
    return message.contains('401');
  }

  void _updateConnectionState(GameSocketConnectionState next) {
    if (_connectionState == next || _connectionEvents.isClosed) {
      return;
    }
    _connectionState = next;
    _connectionEvents.add(next);
    _debugLog('connection-state', {'state': next.name});
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
