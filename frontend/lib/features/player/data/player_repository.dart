import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/realtime/game_socket.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../domain/player_state.dart';

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(
    ref.watch(dioProvider),
    ref.watch(gameSocketProvider),
  );
});

final playerStateProvider = FutureProvider<PlayerState>((ref) async {
  await ref.watch(appBootstrapProvider.future);
  return ref.watch(playerRepositoryProvider).fetch();
});

class PlayerRepository {
  const PlayerRepository(this._dio, this._socket);

  final Dio _dio;
  final GameSocket _socket;

  Future<PlayerState> fetch() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/player');
    final data = unwrapData(response.data);
    return PlayerState.fromJson(data['player'] as Map<String, dynamic>);
  }

  Future<PlayerState> moveTo({required int x, required int y}) async {
    try {
      final data = await _socket.request(
        'player.move',
        payload: {'target_x': x, 'target_y': y},
      );
      return PlayerState.fromJson(data['player'] as Map<String, dynamic>);
    } catch (_) {
      // Keep HTTP as a fallback while the realtime path reconnects or refreshes.
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/player/move',
      data: {'target_x': x, 'target_y': y},
    );
    final data = unwrapData(response.data);
    return PlayerState.fromJson(data['player'] as Map<String, dynamic>);
  }

  Future<PlayerAction> startHarvest({required String entityId}) async {
    try {
      final data = await _socket.request(
        'actions.harvest',
        payload: {'entity_id': entityId},
      );
      return PlayerAction.fromJson(data['action'] as Map<String, dynamic>);
    } catch (_) {
      // Keep HTTP as a fallback while the realtime path reconnects or refreshes.
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/actions/harvest',
      data: {'entity_id': entityId},
    );
    final data = unwrapData(response.data);
    return PlayerAction.fromJson(data['action'] as Map<String, dynamic>);
  }
}
