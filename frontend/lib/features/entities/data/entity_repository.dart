import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/game_socket.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../domain/world_entity.dart';

final entityRepositoryProvider = Provider<EntityRepository>((ref) {
  return EntityRepository(ref.watch(gameSocketProvider));
});

final worldEntitiesProvider = StreamProvider<List<WorldEntity>>((ref) async* {
  await ref.watch(appBootstrapProvider.future);
  final repository = ref.watch(entityRepositoryProvider);
  final socket = ref.watch(gameSocketProvider);
  final controller = StreamController<List<WorldEntity>>();
  final subscription = socket.messagesOfType('entities.updated').listen((data) {
    controller.add(repository.parseEntities(data));
  });

  ref.onDispose(subscription.cancel);
  ref.onDispose(controller.close);

  controller.add(await repository.fetch());
  yield* controller.stream;
});

class EntityRepository {
  const EntityRepository(this._socket);

  final GameSocket _socket;

  Future<List<WorldEntity>> fetch() async {
    final data = await _socket.request('entities.get');
    return parseEntities(data);
  }

  List<WorldEntity> parseEntities(Map<String, dynamic> data) {
    final entities = data['entities'] as List<dynamic>? ?? const [];
    return entities
        .map((entity) => WorldEntity.fromJson(entity as Map<String, dynamic>))
        .toList();
  }
}
