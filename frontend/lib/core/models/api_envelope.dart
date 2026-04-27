part 'api_envelope_parts/api_error_body.dart';

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
