part of '../token_storage.dart';

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
      await _fallback.write(tokens);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _primary.clear();
    } catch (_) {
    }
    await _fallback.clear();
  }
}
