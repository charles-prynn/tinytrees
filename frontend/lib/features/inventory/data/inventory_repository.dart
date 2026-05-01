import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/game_socket.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../domain/inventory_item.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(gameSocketProvider));
});

final inventoryProvider = StreamProvider<List<InventoryItem>>((ref) async* {
  await ref.watch(appBootstrapProvider.future);
  final repository = ref.watch(inventoryRepositoryProvider);
  final socket = ref.watch(gameSocketProvider);
  final controller = StreamController<List<InventoryItem>>();
  var disposed = false;
  var seeded = false;
  var lastConnectionState = GameSocketConnectionState.connected;

  Future<void> seedFromSnapshotWithRetry() async {
    while (!disposed && !seeded) {
      try {
        final items = await repository.fetch();
        if (disposed || seeded) {
          return;
        }
        controller.add(items);
        seeded = true;
        return;
      } catch (error, stackTrace) {
        if (disposed || seeded) {
          return;
        }
        controller.addError(error, stackTrace);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
  }

  Future<void> refreshSnapshot() async {
    try {
      final items = await repository.fetch();
      if (disposed) {
        return;
      }
      controller.add(items);
      seeded = true;
    } catch (error, stackTrace) {
      if (disposed) {
        return;
      }
      controller.addError(error, stackTrace);
    }
  }

  final inventorySubscription = socket.messagesOfType('inventory.updated').listen(
    (data) {
      try {
        controller.add(repository.parseItems(data));
        seeded = true;
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    },
  );
  final connectionSubscription = socket.connectionStates.listen((state) {
    final shouldRefresh =
        state == GameSocketConnectionState.connected &&
        lastConnectionState != GameSocketConnectionState.connected;
    lastConnectionState = state;
    if (shouldRefresh) {
      unawaited(refreshSnapshot());
    }
  });

  ref.onDispose(() {
    disposed = true;
    unawaited(inventorySubscription.cancel());
    unawaited(connectionSubscription.cancel());
    unawaited(controller.close());
  });

  unawaited(seedFromSnapshotWithRetry());
  yield* controller.stream;
});

class InventoryRepository {
  const InventoryRepository(this._socket);

  final GameSocket _socket;

  Future<List<InventoryItem>> fetch() async {
    final data = await _socket.request('inventory.get');
    return parseItems(data);
  }

  List<InventoryItem> parseItems(Map<String, dynamic> data) {
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
