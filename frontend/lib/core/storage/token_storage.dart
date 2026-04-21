import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return ResilientTokenStorage(
    primary: SecureTokenStorage(const FlutterSecureStorage()),
    fallback: SharedPreferencesTokenStorage(),
  );
});

abstract interface class TokenStorage {
  Future<TokenPair?> read();
  Future<void> write(TokenPair tokens);
  Future<void> clear();
}

class TokenPair {
  const TokenPair({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;
}

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

class SharedPreferencesTokenStorage implements TokenStorage {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  @override
  Future<TokenPair?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_accessTokenKey);
    final refresh = prefs.getString(_refreshTokenKey);
    if (access == null || refresh == null) return null;
    return TokenPair(accessToken: access, refreshToken: refresh);
  }

  @override
  Future<void> write(TokenPair tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, tokens.accessToken);
    await prefs.setString(_refreshTokenKey, tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }
}

class ResilientTokenStorage implements TokenStorage {
  const ResilientTokenStorage({
    required TokenStorage primary,
    required TokenStorage fallback,
  }) : _primary = primary,
       _fallback = fallback;

  final TokenStorage _primary;
  final TokenStorage _fallback;

  @override
  Future<TokenPair?> read() async {
    try {
      final tokens = await _primary.read();
      return tokens ?? _fallback.read();
    } catch (_) {
      return _fallback.read();
    }
  }

  @override
  Future<void> write(TokenPair tokens) async {
    try {
      await _primary.write(tokens);
      await _fallback.clear();
    } catch (_) {
      // iOS simulators can reject Keychain access when the app is ad-hoc signed.
      await _fallback.write(tokens);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _primary.clear();
    } catch (_) {
      // The fallback still needs to be cleared if secure storage is unavailable.
    }
    await _fallback.clear();
  }
}
