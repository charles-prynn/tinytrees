part of '../token_storage.dart';

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage(this._storage);

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _operationTimeout = Duration(seconds: 3);

  final FlutterSecureStorage _storage;

  @override
  Future<TokenPair?> read() async {
    final access = await _withTimeout(_storage.read(key: _accessTokenKey));
    final refresh = await _withTimeout(_storage.read(key: _refreshTokenKey));
    if (access == null || refresh == null) return null;
    return TokenPair(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> write(TokenPair tokens) async {
    await _withTimeout(
      _storage.write(key: _accessTokenKey, value: tokens.accessToken),
    );
    await _withTimeout(
      _storage.write(key: _refreshTokenKey, value: tokens.refreshToken),
    );
  }

  @override
  Future<void> clear() async {
    await _withTimeout(_storage.delete(key: _accessTokenKey));
    await _withTimeout(_storage.delete(key: _refreshTokenKey));
  }

  Future<T?> _withTimeout<T>(Future<T?> operation) {
    return operation.timeout(_operationTimeout, onTimeout: () => null);
  }
}
