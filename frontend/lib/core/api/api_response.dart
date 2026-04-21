import '../errors/app_error.dart';

Map<String, dynamic> unwrapData(Object? responseData) {
  if (responseData is! Map<String, dynamic>) {
    throw const AppError('Invalid API response');
  }
  final error = responseData['error'];
  if (error is Map<String, dynamic>) {
    throw AppError(
      error['message'] as String? ?? 'API request failed',
      code: error['code'] as String?,
    );
  }
  final data = responseData['data'];
  if (data is! Map<String, dynamic>) {
    throw const AppError('API response did not include an object payload');
  }
  return data;
}
