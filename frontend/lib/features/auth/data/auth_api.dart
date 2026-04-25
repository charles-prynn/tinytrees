import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});

class AuthApi {
  const AuthApi(this._dio);

  final Dio _dio;

  Future<GuestLoginResponse> guestLogin() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/guest/login',
    );
    final data = unwrapData(response.data);
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    final tokens = _parseTokens(data['tokens'] as Map<String, dynamic>);
    return GuestLoginResponse(user: user, tokens: tokens);
  }

  Future<GuestLoginResponse> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/login',
      data: {'username': username, 'password': password},
    );
    final data = unwrapData(response.data);
    final user = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    final tokens = _parseTokens(data['tokens'] as Map<String, dynamic>);
    return GuestLoginResponse(user: user, tokens: tokens);
  }

  Future<AppUser> me() async {
    final response = await _dio.get<Map<String, dynamic>>('/v1/me');
    final data = unwrapData(response.data);
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _dio.post<Map<String, dynamic>>('/v1/auth/logout');
  }

  Future<AppUser> upgradeGuest({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/auth/guest/upgrade',
      data: {'username': username, 'email': '', 'password': password},
    );
    final data = unwrapData(response.data);
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  TokenPair _parseTokens(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }
}

class GuestLoginResponse {
  const GuestLoginResponse({required this.user, required this.tokens});

  final AppUser user;
  final TokenPair tokens;
}
