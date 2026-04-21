import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/network/dio_provider.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../domain/tile_map.dart';

final mapRepositoryProvider = Provider<MapRepository>((ref) {
  return MapRepository(ref.watch(dioProvider));
});

final tileMapProvider = FutureProvider<TileMap>((ref) async {
  await ref.watch(appBootstrapProvider.future);
  return ref.watch(mapRepositoryProvider).fetch();
});

class MapRepository {
  const MapRepository(this._dio);

  final Dio _dio;

  Future<TileMap> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/map');
    final data = unwrapData(response.data);
    return TileMap.fromJson(data['map'] as Map<String, dynamic>);
  }
}
