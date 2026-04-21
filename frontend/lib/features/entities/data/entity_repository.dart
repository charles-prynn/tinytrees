import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/network/dio_provider.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../domain/world_entity.dart';

final entityRepositoryProvider = Provider<EntityRepository>((ref) {
  return EntityRepository(ref.watch(dioProvider));
});

final worldEntitiesProvider = FutureProvider<List<WorldEntity>>((ref) async {
  await ref.watch(appBootstrapProvider.future);
  return ref.watch(entityRepositoryProvider).fetch();
});

class EntityRepository {
  const EntityRepository(this._dio);

  final Dio _dio;

  Future<List<WorldEntity>> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/entities');
    final data = unwrapData(response.data);
    final entities = data['entities'] as List<dynamic>? ?? const [];
    return entities
        .map((entity) => WorldEntity.fromJson(entity as Map<String, dynamic>))
        .toList();
  }
}
