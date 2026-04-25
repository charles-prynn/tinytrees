import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      return null;
    });
  }
}
