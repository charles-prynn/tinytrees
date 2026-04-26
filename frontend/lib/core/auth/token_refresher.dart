import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

final tokenRefresherProvider = Provider<TokenRefresher>((ref) {
  return TokenRefresher(
    tokenStorage: ref.watch(tokenStorageProvider),
    refreshClient: Dio(
      BaseOptions(
        baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    ),
  );
});

class TokenRefresher {
  TokenRefresher({
    required TokenStorage tokenStorage,
    required Dio refreshClient,
  }) : _tokenStorage = tokenStorage,
       _refreshClient = refreshClient;

  final TokenStorage _tokenStorage;
  final Dio _refreshClient;
  Future<TokenPair?>? _refreshInFlight;

  Future<TokenPair?> refreshTokens() {
    _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
    return _refreshInFlight!;
  }

  Future<TokenPair?> _doRefresh() async {
    final current = await _tokenStorage.read();
    if (current == null) {
      return null;
    }

    try {
      final response = await _refreshClient.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refresh_token': current.refreshToken},
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      final tokenJson = data?['tokens'] as Map<String, dynamic>?;
      if (tokenJson == null) {
        return null;
      }

      final next = TokenPair(
        accessToken: tokenJson['access_token'] as String,
        refreshToken: tokenJson['refresh_token'] as String,
      );
      await _tokenStorage.write(next);
      return next;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 400 || statusCode == 401) {
        await _tokenStorage.clear();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
