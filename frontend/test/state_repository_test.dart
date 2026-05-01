import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treescape/core/errors/app_error.dart';
import 'package:treescape/core/storage/local_cache.dart';
import 'package:treescape/features/state/data/state_repository.dart';

void main() {
  test('fetch falls back to cached state for transient transport failures', () async {
    final dio = Dio()..httpClientAdapter = _FakeAdapter.connectionError();
    final cache = _FakeLocalCache()
      ..stored['state_snapshot'] = '{"version":7,"metadata":{"zone":"oak"}}';
    final repository = StateRepository(dio: dio, cache: cache);

    final snapshot = await repository.fetch();

    expect(snapshot.version, 7);
    expect(snapshot.metadata['zone'], 'oak');
  });

  test('fetch does not hide malformed API payloads behind cached state', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter.jsonResponse({
        'data': 'not-an-object',
      });
    final cache = _FakeLocalCache()
      ..stored['state_snapshot'] = '{"version":7,"metadata":{"zone":"oak"}}';
    final repository = StateRepository(dio: dio, cache: cache);

    await expectLater(repository.fetch(), throwsA(isA<AppError>()));
  });

  test('fetch does not hide unauthorized responses behind cached state', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeAdapter.jsonResponse(
        {'error': 'unauthorized'},
        statusCode: 401,
      );
    final cache = _FakeLocalCache()
      ..stored['state_snapshot'] = '{"version":7,"metadata":{"zone":"oak"}}';
    final repository = StateRepository(dio: dio, cache: cache);

    await expectLater(repository.fetch(), throwsA(isA<DioException>()));
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter._({
    this.responseBody,
    this.error,
  });

  factory _FakeAdapter.connectionError() {
    return _FakeAdapter._(
      error: DioException(
        requestOptions: RequestOptions(path: '/v1/state'),
        type: DioExceptionType.connectionError,
        error: Exception('offline'),
      ),
    );
  }

  factory _FakeAdapter.jsonResponse(
    Map<String, dynamic> body, {
    int statusCode = 200,
  }) {
    return _FakeAdapter._(
      responseBody: ResponseBody.fromString(
        jsonEncode(body),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
  }

  final ResponseBody? responseBody;
  final Object? error;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (error != null) {
      throw error!;
    }
    return responseBody!;
  }

  @override
  void close({bool force = false}) {}
}

class _FakeLocalCache implements LocalCache {
  final Map<String, String> stored = {};

  @override
  Future<String?> readString(String key) async {
    return stored[key];
  }

  @override
  Future<void> remove(String key) async {
    stored.remove(key);
  }

  @override
  Future<void> writeString(String key, String value) async {
    stored[key] = value;
  }
}
