import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/game_socket.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../../entities/data/entity_repository.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../map/application/map_controller.dart';
import '../../player/application/player_controller.dart';
import '../../state/data/state_repository.dart';
import '../domain/auth_session.dart';
import 'auth_repository.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    return ref.watch(authRepositoryProvider).restoreOrLoginGuest();
  }

  Future<void> upgradeGuest({
    required String username,
    required String password,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    final previous = state.value;
    try {
      state = const AsyncLoading();
      final session = await repository.upgradeGuest(
        username: username,
        password: password,
      );
      state = AsyncData(session);
      _refreshGameSession();
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final repository = ref.read(authRepositoryProvider);
    final previous = state.value;
    try {
      state = const AsyncLoading();
      final session = await repository.login(
        username: username,
        password: password,
      );
      state = AsyncData(session);
      _refreshGameSession();
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.logout();
      _refreshGameSession();
      return null;
    });
  }

  void _refreshGameSession() {
    ref.invalidate(gameSocketProvider);
    ref.invalidate(gameSocketConnectionProvider);
    ref.invalidate(appBootstrapProvider);
    ref.invalidate(mapControllerProvider);
    ref.invalidate(worldEntitiesProvider);
    ref.invalidate(playerControllerProvider);
    ref.invalidate(inventoryProvider);
    ref.invalidate(stateSnapshotProvider);
  }
}
