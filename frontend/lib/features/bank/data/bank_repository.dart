import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/game_socket.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../../inventory/domain/inventory_item.dart';

final bankRepositoryProvider = Provider<BankRepository>((ref) {
  return BankRepository(ref.watch(gameSocketProvider));
});

final bankProvider = StreamProvider<List<InventoryItem>>((ref) async* {
  await ref.watch(appBootstrapProvider.future);
  final repository = ref.watch(bankRepositoryProvider);
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

  final bankSubscription = socket.messagesOfType('bank.updated').listen((data) {
    try {
      controller.add(repository.parseItems(data));
      seeded = true;
    } catch (error, stackTrace) {
      controller.addError(error, stackTrace);
    }
  });
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
    unawaited(bankSubscription.cancel());
    unawaited(connectionSubscription.cancel());
    unawaited(controller.close());
  });

  unawaited(seedFromSnapshotWithRetry());
  yield* controller.stream;
});

class BankRepository {
  const BankRepository(this._socket);

  final GameSocket _socket;

  Future<List<InventoryItem>> fetch() async {
    final data = await _socket.request('bank.get');
    return parseItems(data);
  }

  Future<void> deposit({
    required String entityId,
    required String itemKey,
    required int quantity,
  }) async {
    await _socket.request(
      'bank.deposit',
      payload: {
        'entity_id': entityId,
        'item_key': itemKey,
        'quantity': quantity,
      },
    );
  }

  List<InventoryItem> parseItems(Map<String, dynamic> data) {
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
