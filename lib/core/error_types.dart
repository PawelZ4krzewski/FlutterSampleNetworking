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
  String toString() => 'AppError(type: $type, statusCode: $statusCode, message: $message)';
}

/// Map DioException to AppError
AppError mapDioException(DioException e) {
  final status = e.response?.statusCode;
  // Connection related
  if (e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout) {
    return AppError(type: AppErrorType.timeout, message: 'Request timed out', raw: e);
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
    return AppError(type: AppErrorType.cancel, message: 'Request cancelled', raw: e);
  }

  // Network down/offline
  if (e.type == DioExceptionType.connectionError || e.error is SocketException) {
    return AppError(type: AppErrorType.offline, message: 'No internet connection', raw: e);
  }

  return AppError(type: AppErrorType.unknown, message: 'Unknown error', raw: e, statusCode: status);
}
