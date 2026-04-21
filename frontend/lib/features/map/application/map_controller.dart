import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/map_repository.dart';
import '../domain/tile_map.dart';

final mapControllerProvider = AsyncNotifierProvider<MapController, TileMap>(
  MapController.new,
);

class MapController extends AsyncNotifier<TileMap> {
  @override
  Future<TileMap> build() async {
    return ref.watch(tileMapProvider.future);
  }
}
