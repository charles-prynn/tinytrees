import 'package:dio/dio.dart';

import '../auth/token_refresher.dart';
import '../storage/token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required TokenRefresher tokenRefresher,
    required Dio retryClient,
  }) : _tokenStorage = tokenStorage,
       _tokenRefresher = tokenRefresher,
       _retryClient = retryClient;

  final TokenStorage _tokenStorage;
  final TokenRefresher _tokenRefresher;
  final Dio _retryClient;

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

    final refreshed = await _tokenRefresher.refreshTokens();
    if (refreshed == null) {
      handler.next(err);
      return;
    }

    final request = err.requestOptions;
    request.extra['retried'] = true;
    request.headers['Authorization'] = 'Bearer ${refreshed.accessToken}';

    try {
      final response = await _retryClient.fetch<dynamic>(request);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }
}
