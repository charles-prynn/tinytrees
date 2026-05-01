import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treescape/core/storage/token_storage.dart';
import 'package:treescape/features/auth/data/auth_api.dart';
import 'package:treescape/features/auth/data/auth_repository.dart';
import 'package:treescape/features/auth/domain/user.dart';

void main() {
  test('restoreOrLoginGuest reuses stored tokens when /me succeeds', () async {
    final storage = _FakeTokenStorage(
      tokens: const TokenPair(accessToken: 'stored-a', refreshToken: 'stored-r'),
    );
    final api = _FakeAuthApi()
      ..meResult = const AppUser(
        id: 'user-1',
        provider: 'local',
        displayName: 'player_one',
      );
    final repository = AuthRepository(api: api, tokenStorage: storage);

    final session = await repository.restoreOrLoginGuest();

    expect(session.user.displayName, 'player_one');
    expect(api.meCalls, 1);
    expect(api.guestLoginCalls, 0);
    expect(storage.clearCalls, 0);
    expect(storage.writeCalls, 0);
  });

  test('restoreOrLoginGuest clears stale tokens and falls back to guest login', () async {
    final storage = _FakeTokenStorage(
      tokens: const TokenPair(accessToken: 'stale-a', refreshToken: 'stale-r'),
    );
    final api = _FakeAuthApi()
      ..meError = Exception('expired token')
      ..guestLoginResult = GuestLoginResponse(
        user: const AppUser(
          id: 'guest-1',
          provider: 'guest',
          displayName: 'Guest',
        ),
        tokens: const TokenPair(
          accessToken: 'guest-a',
          refreshToken: 'guest-r',
        ),
      );
    final repository = AuthRepository(api: api, tokenStorage: storage);

    final session = await repository.restoreOrLoginGuest();

    expect(session.user.provider, 'guest');
    expect(api.meCalls, 1);
    expect(api.guestLoginCalls, 1);
    expect(storage.clearCalls, 1);
    expect(storage.lastWrittenTokens?.accessToken, 'guest-a');
    expect(storage.lastWrittenTokens?.refreshToken, 'guest-r');
  });

  test('login persists the returned token pair', () async {
    final storage = _FakeTokenStorage();
    final api = _FakeAuthApi()
      ..loginResult = GuestLoginResponse(
        user: const AppUser(
          id: 'user-2',
          provider: 'local',
          displayName: 'lumberjack',
        ),
        tokens: const TokenPair(
          accessToken: 'login-a',
          refreshToken: 'login-r',
        ),
      );
    final repository = AuthRepository(api: api, tokenStorage: storage);

    final session = await repository.login(
      username: 'lumberjack',
      password: 'secret',
    );

    expect(session.user.displayName, 'lumberjack');
    expect(api.lastLoginUsername, 'lumberjack');
    expect(api.lastLoginPassword, 'secret');
    expect(storage.lastWrittenTokens?.accessToken, 'login-a');
    expect(storage.lastWrittenTokens?.refreshToken, 'login-r');
  });

  test('logout clears local tokens even when the API call fails', () async {
    final storage = _FakeTokenStorage(
      tokens: const TokenPair(accessToken: 'a', refreshToken: 'r'),
    );
    final api = _FakeAuthApi()..logoutError = Exception('network error');
    final repository = AuthRepository(api: api, tokenStorage: storage);

    await expectLater(repository.logout(), throwsException);

    expect(api.logoutCalls, 1);
    expect(storage.clearCalls, 1);
    expect(storage.tokens, isNull);
  });
}

class _FakeAuthApi extends AuthApi {
  _FakeAuthApi() : super(Dio());

  int meCalls = 0;
  int guestLoginCalls = 0;
  int logoutCalls = 0;
  String? lastLoginUsername;
  String? lastLoginPassword;

  AppUser? meResult;
  Object? meError;
  GuestLoginResponse? guestLoginResult;
  GuestLoginResponse? loginResult;
  Object? logoutError;

  @override
  Future<AppUser> me() async {
    meCalls++;
    if (meError != null) {
      throw meError!;
    }
    return meResult!;
  }

  @override
  Future<GuestLoginResponse> guestLogin() async {
    guestLoginCalls++;
    return guestLoginResult!;
  }

  @override
  Future<GuestLoginResponse> login({
    required String username,
    required String password,
  }) async {
    lastLoginUsername = username;
    lastLoginPassword = password;
    return loginResult!;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    if (logoutError != null) {
      throw logoutError!;
    }
  }
}

class _FakeTokenStorage implements TokenStorage {
  _FakeTokenStorage({this.tokens});

  TokenPair? tokens;

  int clearCalls = 0;
  int writeCalls = 0;
  TokenPair? lastWrittenTokens;

  @override
  Future<void> clear() async {
    clearCalls++;
    tokens = null;
  }

  @override
  Future<TokenPair?> read() async {
    return tokens;
  }

  @override
  Future<void> write(TokenPair tokens) async {
    writeCalls++;
    lastWrittenTokens = tokens;
    this.tokens = tokens;
  }
}
