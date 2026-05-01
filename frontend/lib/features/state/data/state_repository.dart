import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_response.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/storage/local_cache.dart';
import '../../bootstrap/data/bootstrap_repository.dart';
import '../domain/state_snapshot.dart';

final stateRepositoryProvider = Provider<StateRepository>((ref) {
  return StateRepository(
    dio: ref.watch(dioProvider),
    cache: ref.watch(localCacheProvider),
  );
});

final stateSnapshotProvider = FutureProvider<StateSnapshot>((ref) async {
  await ref.watch(appBootstrapProvider.future);
  return ref.watch(stateRepositoryProvider).fetch();
});

class StateRepository {
  const StateRepository({required Dio dio, required LocalCache cache})
    : _dio = dio,
      _cache = cache;

  static const _cacheKey = 'state_snapshot';

  final Dio _dio;
  final LocalCache _cache;

  Future<StateSnapshot> fetch() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/v1/state');
      final data = unwrapData(response.data);
      final snapshot = StateSnapshot.fromJson(
        data['snapshot'] as Map<String, dynamic>,
      );
      await _cache.writeString(_cacheKey, jsonEncode(snapshot.toSyncJson()));
      return snapshot;
    } catch (error) {
      if (!_shouldUseCachedSnapshot(error)) {
        rethrow;
      }
      final cached = await _cache.readString(_cacheKey);
      if (cached != null) {
        return StateSnapshot.fromJson(
          jsonDecode(cached) as Map<String, dynamic>,
        );
      }
      rethrow;
    }
  }

  Future<StateSnapshot> sync(StateSnapshot snapshot) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/state/sync',
      data: snapshot.toSyncJson(),
    );
    final data = unwrapData(response.data);
    final next = StateSnapshot.fromJson(
      data['snapshot'] as Map<String, dynamic>,
    );
    await _cache.writeString(_cacheKey, jsonEncode(next.toSyncJson()));
    return next;
  }

  bool _shouldUseCachedSnapshot(Object error) {
    if (error is! DioException) {
      return false;
    }

    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      return statusCode >= 500;
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
        return false;
      case DioExceptionType.unknown:
        return error.response == null;
    }
  }
}
