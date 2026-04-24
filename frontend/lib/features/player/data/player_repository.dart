import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/game_socket.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../domain/player_state.dart';

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(ref.watch(gameSocketProvider));
});

final playerStateProvider = FutureProvider<PlayerState>((ref) async {
  await ref.watch(appBootstrapProvider.future);
  return ref.watch(playerRepositoryProvider).fetch();
});

class PlayerRepository {
  const PlayerRepository(this._socket);

  final GameSocket _socket;

  Future<PlayerState> fetch() async {
    final data = await _socket.request('player.get');
    return PlayerState.fromJson(data['player'] as Map<String, dynamic>);
  }

  Future<PlayerState> moveTo({required int x, required int y}) async {
    final data = await _socket.request(
      'player.move',
      payload: {'target_x': x, 'target_y': y},
    );
    return PlayerState.fromJson(data['player'] as Map<String, dynamic>);
  }

  Future<PlayerAction> startHarvest({required String entityId}) async {
    final data = await _socket.request(
      'actions.harvest',
      payload: {'entity_id': entityId},
    );
    return PlayerAction.fromJson(data['action'] as Map<String, dynamic>);
  }
}
