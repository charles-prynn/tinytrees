import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/token_storage.dart';
import '../domain/auth_session.dart';
import 'auth_api.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(authApiProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

class AuthRepository {
  const AuthRepository({
    required AuthApi api,
    required TokenStorage tokenStorage,
  }) : _api = api,
       _tokenStorage = tokenStorage;

  final AuthApi _api;
  final TokenStorage _tokenStorage;

  Future<AuthSession> restoreOrLoginGuest() async {
    final tokens = await _tokenStorage.read();
    if (tokens != null) {
      try {
        final user = await _api.me();
        return AuthSession(user: user);
      } catch (_) {
        await _tokenStorage.clear();
      }
    }

    final login = await _api.guestLogin();
    await _tokenStorage.write(login.tokens);
    return AuthSession(user: login.user);
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } finally {
      await _tokenStorage.clear();
    }
  }

  Future<AuthSession> upgradeGuest({
    required String username,
    required String password,
  }) async {
    final user = await _api.upgradeGuest(
      username: username,
      password: password,
    );
    return AuthSession(user: user);
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final login = await _api.login(username: username, password: password);
    await _tokenStorage.write(login.tokens);
    return AuthSession(user: login.user);
  }
}
