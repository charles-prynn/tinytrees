import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'token_storage_parts/token_pair.dart';
part 'token_storage_parts/secure_token_storage.dart';
part 'token_storage_parts/shared_preferences_token_storage.dart';
part 'token_storage_parts/resilient_token_storage.dart';

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
