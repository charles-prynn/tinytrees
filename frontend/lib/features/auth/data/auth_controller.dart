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

  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await repository.logout();
      return null;
    });
  }
}
