part of '../api_envelope.dart';

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
