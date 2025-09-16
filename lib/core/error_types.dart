import 'dart:io';
import 'package:dio/dio.dart';

enum AppErrorType { offline, timeout, client4xx, server5xx, cancel, unknown }

class AppError {
  final AppErrorType type;
  final String message;
  final int? statusCode;
  final Object? raw;

  const AppError({
    required this.type,
    required this.message,
    this.statusCode,
    this.raw,
  });

  @override
  String toString() =>
      'AppError(type: $type, statusCode: $statusCode, message: $message)';
}

AppError mapDioException(DioException e) {
  final status = e.response?.statusCode;
  // Platform-specific timeout may surface as connectionError with timeout wording
  if (e.type == DioExceptionType.connectionError) {
    final msg = (e.message ?? '').toLowerCase();
    if (msg.contains('timed out') || msg.contains('timeout')) {
      return AppError(type: AppErrorType.timeout, message: 'Request timed out', raw: e);
    }
    if (e.error is SocketException) {
      return AppError(type: AppErrorType.offline, message: 'No internet connection', raw: e);
    }
  }
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return AppError(
        type: AppErrorType.timeout, message: 'Request timed out', raw: e);
  }

  if (e.type == DioExceptionType.badResponse) {
    if (status != null && status >= 500) {
      return AppError(
        type: AppErrorType.server5xx,
        message: 'Server error ($status)',
        statusCode: status,
        raw: e,
      );
    }
    if (status != null && status >= 400 && status < 500) {
      return AppError(
        type: AppErrorType.client4xx,
        message: 'Client error ($status)',
        statusCode: status,
        raw: e,
      );
    }
  }

  if (e.type == DioExceptionType.cancel) {
    return AppError(
        type: AppErrorType.cancel, message: 'Request cancelled', raw: e);
  }

  if (e.type == DioExceptionType.connectionError ||
      e.error is SocketException) {
    return AppError(
        type: AppErrorType.offline, message: 'No internet connection', raw: e);
  }

  return AppError(
      type: AppErrorType.unknown,
      message: 'Unknown error',
      raw: e,
      statusCode: status);
}
