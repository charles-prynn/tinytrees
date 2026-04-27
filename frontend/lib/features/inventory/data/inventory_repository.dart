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
  while (true) {
    yield await repository.fetch();
    await Future<void>.delayed(const Duration(seconds: 1));
  }
});

class InventoryRepository {
  const InventoryRepository(this._socket);

  final GameSocket _socket;

  Future<List<InventoryItem>> fetch() async {
    final data = await _socket.request('inventory.get');
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
