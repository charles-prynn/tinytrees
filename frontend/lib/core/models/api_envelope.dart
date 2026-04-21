class ApiEnvelope<T> {
  const ApiEnvelope({this.data, this.error, this.requestId});

  final T? data;
  final ApiErrorBody? error;
  final String? requestId;

  factory ApiEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(Object? json) decodeData,
  ) {
    return ApiEnvelope<T>(
      data: json['data'] == null ? null : decodeData(json['data']),
      error:
          json['error'] == null
              ? null
              : ApiErrorBody.fromJson(json['error'] as Map<String, dynamic>),
      requestId: json['request_id'] as String?,
    );
  }
}

class ApiErrorBody {
  const ApiErrorBody({required this.code, required this.message});

  final String code;
  final String message;

  factory ApiErrorBody.fromJson(Map<String, dynamic> json) {
    return ApiErrorBody(
      code: json['code'] as String? ?? 'unknown_error',
      message: json['message'] as String? ?? 'Unknown error',
    );
  }
}
