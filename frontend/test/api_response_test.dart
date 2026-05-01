import 'package:flutter_test/flutter_test.dart';
import 'package:treescape/core/api/api_response.dart';
import 'package:treescape/core/errors/app_error.dart';

void main() {
  test('unwrapData returns the nested data payload', () {
    final data = unwrapData({
      'data': {'version': 7, 'name': 'Treescape'},
    });

    expect(data, {'version': 7, 'name': 'Treescape'});
  });

  test('unwrapData surfaces API errors as AppError', () {
    expect(
      () => unwrapData({
        'error': {'code': 'unauthorized', 'message': 'Nope'},
      }),
      throwsA(
        isA<AppError>()
            .having((error) => error.code, 'code', 'unauthorized')
            .having((error) => error.message, 'message', 'Nope'),
      ),
    );
  });

  test('unwrapData rejects malformed responses', () {
    expect(() => unwrapData(null), throwsA(isA<AppError>()));
    expect(
      () => unwrapData({'data': 'not-an-object'}),
      throwsA(isA<AppError>()),
    );
  });
}
