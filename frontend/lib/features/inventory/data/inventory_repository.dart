import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/network/dio_provider.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../domain/inventory_item.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(dioProvider));
});

final inventoryProvider = FutureProvider<List<InventoryItem>>((ref) async {
  await ref.watch(appBootstrapProvider.future);
  return ref.watch(inventoryRepositoryProvider).fetch();
});

class InventoryRepository {
  const InventoryRepository(this._dio);

  final Dio _dio;

  Future<List<InventoryItem>> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/inventory');
    final data = unwrapData(response.data);
    final items = data['items'] as List<dynamic>? ?? const [];
    return items
        .map((item) => InventoryItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
