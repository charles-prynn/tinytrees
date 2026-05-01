import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treescape/core/auth/token_refresher.dart';
import 'package:treescape/core/config/app_config.dart';
import 'package:treescape/core/realtime/game_socket.dart';
import 'package:treescape/core/storage/token_storage.dart';
import 'package:treescape/features/bootstrap/data/bootstrap_repository.dart';
import 'package:treescape/features/bootstrap/domain/bootstrap_config.dart';
import 'package:treescape/features/inventory/data/inventory_repository.dart';
import 'package:treescape/features/inventory/domain/inventory_item.dart';
import 'package:treescape/features/player/application/player_controller.dart';
import 'package:treescape/features/player/data/player_repository.dart';
import 'package:treescape/features/player/domain/player_state.dart';

void main() {
  test(
    'inventory provider stays alive after a failed snapshot fetch and recovers from realtime updates',
    () async {
      final socket = _FakeGameSocket();
      socket.queueRequestError('inventory.get', Exception('temporary failure'));

      final container = ProviderContainer(
        overrides: [
          appBootstrapProvider.overrideWith((ref) async => _bootstrap),
          gameSocketProvider.overrideWith((ref) {
            ref.onDispose(socket.close);
            return socket;
          }),
          inventoryRepositoryProvider.overrideWith(
            (ref) => InventoryRepository(socket),
          ),
        ],
      );
      addTearDown(container.dispose);

      final states = <AsyncValue<List<InventoryItem>>>[];
      final subscription = container.listen(
        inventoryProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await _waitFor(() => states.any((state) => state.hasError));

      socket.emit('inventory.updated', {
        'items': [
          {'item_key': 'wood', 'quantity': 12},
        ],
      });

      await _waitFor(
        () =>
            states.isNotEmpty &&
            states.last.hasValue &&
            states.last.requireValue.single.quantity == 12,
      );

      expect(states.last.requireValue.single.itemKey, 'wood');
    },
  );

  test(
    'player controller updates from realtime events without background polling',
    () async {
      final socket = _FakeGameSocket();
      final repository = _FakePlayerRepository(socket);
      final container = ProviderContainer(
        overrides: [
          gameSocketProvider.overrideWith((ref) {
            ref.onDispose(socket.close);
            return socket;
          }),
          playerRepositoryProvider.overrideWith((ref) => repository),
          playerStateProvider.overrideWith((ref) async => _playerState(x: 4)),
        ],
      );
      addTearDown(container.dispose);

      final states = <AsyncValue<PlayerState>>[];
      final subscription = container.listen(
        playerControllerProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      await container.read(playerControllerProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      expect(repository.fetchCalls, 0);

      socket.emit('player.updated', {
        'player': {
          'user_id': 'user-1',
          'x': 7,
          'y': 9,
          'render_x': 7,
          'render_y': 9,
          'skills': const [],
        },
      });

      await _waitFor(
        () =>
            states.isNotEmpty &&
            states.last.hasValue &&
            states.last.requireValue.x == 7 &&
            states.last.requireValue.y == 9,
      );
    },
  );
}

final _bootstrap = AppBootstrap(
  config: BootstrapConfig(
    apiVersion: 'v1',
    features: const ['realtime'],
    serverTime: DateTime.utc(2026, 5, 1),
  ),
);

PlayerState _playerState({required int x}) {
  return PlayerState(
    userId: 'user-1',
    x: x,
    y: 3,
    renderX: x.toDouble(),
    renderY: 3,
    movement: null,
    action: null,
    skills: const [],
    updatedAt: DateTime.utc(2026, 5, 1),
  );
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (predicate()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  expect(predicate(), isTrue);
}

class _FakeGameSocket extends GameSocket {
  _FakeGameSocket()
    : super(
        config: const AppConfig(
          apiBaseUrl: 'http://example.test',
          websocketBaseUrl: 'ws://example.test',
          environment: 'test',
          debugFps: false,
          debugCord: false,
        ),
        tokenStorage: _FakeTokenStorage(),
        tokenRefresher: TokenRefresher(
          tokenStorage: _FakeTokenStorage(),
          refreshClient: Dio(),
        ),
      );

  final Map<String, List<Object>> _queuedRequests = {};
  final Map<String, StreamController<Map<String, dynamic>>> _messageControllers =
      {};
  final StreamController<GameSocketConnectionState> _connectionController =
      StreamController<GameSocketConnectionState>.broadcast();
  GameSocketConnectionState _currentConnectionState =
      GameSocketConnectionState.connected;

  void queueRequest(String type, Map<String, dynamic> response) {
    (_queuedRequests[type] ??= <Object>[]).add(response);
  }

  void queueRequestError(String type, Object error) {
    (_queuedRequests[type] ??= <Object>[]).add(error);
  }

  void emit(String type, Map<String, dynamic> data) {
    (_messageControllers[type] ??=
            StreamController<Map<String, dynamic>>.broadcast())
        .add(data);
  }

  void emitConnection(GameSocketConnectionState state) {
    _currentConnectionState = state;
    _connectionController.add(state);
  }

  @override
  Stream<GameSocketConnectionState> get connectionStates async* {
    yield _currentConnectionState;
    yield* _connectionController.stream;
  }

  @override
  Stream<Map<String, dynamic>> messagesOfType(String type) {
    return (_messageControllers[type] ??=
            StreamController<Map<String, dynamic>>.broadcast())
        .stream;
  }

  @override
  Future<Map<String, dynamic>> request(
    String type, {
    Map<String, dynamic>? payload,
  }) async {
    final queue = _queuedRequests[type];
    if (queue == null || queue.isEmpty) {
      throw StateError('No queued response for $type');
    }

    final next = queue.removeAt(0);
    if (next is Exception || next is Error) {
      throw next;
    }

    return Map<String, dynamic>.from(next as Map<String, dynamic>);
  }

  @override
  Future<void> close() async {
    for (final controller in _messageControllers.values) {
      await controller.close();
    }
    await _connectionController.close();
  }
}

class _FakePlayerRepository extends PlayerRepository {
  _FakePlayerRepository(super.socket);

  int fetchCalls = 0;

  @override
  Future<PlayerState> fetch() async {
    fetchCalls++;
    return _playerState(x: 99);
  }
}

class _FakeTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<TokenPair?> read() async {
    return null;
  }

  @override
  Future<void> write(TokenPair tokens) async {}
}
