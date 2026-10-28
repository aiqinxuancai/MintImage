import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../core/api/openai_client.dart';

class CliException implements Exception {
  const CliException(this.type, this.message, {this.httpStatus});

  final String type;
  final String message;
  final int? httpStatus;

  Map<String, Object?> toJson(Iterable<String> secrets) => {
    'type': type,
    'message': redactCliSecrets(message, secrets),
    if (httpStatus != null) 'http_status': httpStatus,
  };

  @override
  String toString() => message;
}

CliException describeCliError(Object error) {
  if (error is CliException) return error;
  if (error is ApiException) {
    return CliException(
      'api_error',
      error.message,
      httpStatus: error.statusCode,
    );
  }
  if (error is TimeoutException) {
    return CliException('timeout', error.message ?? '任务超时。');
  }
  if (error is DioException) {
    final isTimeout = const [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
    ].contains(error.type);
    return CliException(
      isTimeout ? 'timeout' : 'network_error',
      OpenAiClient.extractErrorMessage(error),
      httpStatus: error.response?.statusCode,
    );
  }
  if (error is FileSystemException) {
    return CliException('io_error', error.toString());
  }
  if (error is FormatException) {
    return CliException('invalid_response', error.message);
  }
  return CliException('internal_error', error.toString());
}

String redactCliSecrets(String message, Iterable<String> secrets) {
  var result = message;
  for (final secret in secrets.where((value) => value.isNotEmpty)) {
    result = result.replaceAll(secret, '[REDACTED]');
  }
  return result.replaceAll(
    RegExp(r'Bearer\s+[^\s"\x27,;]+', caseSensitive: false),
    'Bearer [REDACTED]',
  );
}
