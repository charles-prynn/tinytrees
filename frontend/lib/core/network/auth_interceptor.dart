import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required Dio refreshClient,
  }) : _tokenStorage = tokenStorage,
       _refreshClient = refreshClient;

  final TokenStorage _tokenStorage;
  final Dio _refreshClient;
  Future<TokenPair?>? _refreshInFlight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final tokens = await _tokenStorage.read();
    if (tokens != null) {
      options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final canRetry = err.requestOptions.extra['retried'] != true;
    if (statusCode != 401 || !canRetry) {
      handler.next(err);
      return;
    }

    final refreshed = await _refreshTokens();
    if (refreshed == null) {
      handler.next(err);
      return;
    }

    final request = err.requestOptions;
    request.extra['retried'] = true;
    request.headers['Authorization'] = 'Bearer ${refreshed.accessToken}';

    try {
      final response = await _refreshClient.fetch<dynamic>(request);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }

  Future<TokenPair?> _refreshTokens() {
    _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
    return _refreshInFlight!;
  }

  Future<TokenPair?> _doRefresh() async {
    final current = await _tokenStorage.read();
    if (current == null) return null;

    try {
      final response = await _refreshClient.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refresh_token': current.refreshToken},
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      final tokenJson = data?['tokens'] as Map<String, dynamic>?;
      if (tokenJson == null) return null;

      final next = TokenPair(
        accessToken: tokenJson['access_token'] as String,
        refreshToken: tokenJson['refresh_token'] as String,
      );
      await _tokenStorage.write(next);
      return next;
    } catch (_) {
      await _tokenStorage.clear();
      return null;
    }
  }
}
