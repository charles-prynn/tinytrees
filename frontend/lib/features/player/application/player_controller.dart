import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/realtime/game_socket.dart';
import '../data/player_repository.dart';
import '../domain/player_state.dart';

final playerControllerProvider =
    AsyncNotifierProvider<PlayerController, PlayerState>(PlayerController.new);

class PlayerController extends AsyncNotifier<PlayerState> {
  int _moveSequence = 0;
  bool _refreshInFlight = false;

  @override
  Future<PlayerState> build() async {
    final repository = ref.watch(playerRepositoryProvider);
    final socket = ref.watch(gameSocketProvider);
    final subscription = socket.messagesOfType('player.updated').listen((data) {
      final player = data['player'];
      if (player is Map<String, dynamic>) {
        state = AsyncData(PlayerState.fromJson(player));
      }
    });
    final timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_refreshInFlight) {
        return;
      }
      _refreshInFlight = true;
      try {
        state = AsyncData(await repository.fetch());
      } catch (_) {
        // Keep the previous state if the background refresh fails.
      } finally {
        _refreshInFlight = false;
      }
    });
    ref.onDispose(subscription.cancel);
    ref.onDispose(timer.cancel);
    return ref.watch(playerStateProvider.future);
  }

  Future<bool> moveTo({required int x, required int y}) async {
    final sequence = ++_moveSequence;
    final repository = ref.read(playerRepositoryProvider);
    final previous = state.value;
    try {
      final next = await repository.moveTo(x: x, y: y);
      if (sequence == _moveSequence) {
        state = AsyncData(next);
        return true;
      }
      return false;
    } catch (error, stackTrace) {
      if (sequence == _moveSequence) {
        state =
            previous == null
                ? AsyncError(error, stackTrace)
                : AsyncData(previous);
      }
      return false;
    }
  }

  Future<Object?> startHarvest({required String entityId}) async {
    final sequence = ++_moveSequence;
    final repository = ref.read(playerRepositoryProvider);
    final previous = state.value;
    try {
      await repository.startHarvest(entityId: entityId);
      final next = await repository.fetch();
      if (sequence == _moveSequence) {
        state = AsyncData(next);
        return null;
      }
      return null;
    } catch (error, stackTrace) {
      if (sequence == _moveSequence) {
        state =
            previous == null
                ? AsyncError(error, stackTrace)
                : AsyncData(previous);
      }
      if (error is AppError) {
        return error;
      }
      return AppError(error.toString(), cause: error);
    }
  }
}
