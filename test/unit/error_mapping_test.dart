import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sample_networking/core/error_types.dart';

void main() {
  group('DioException -> AppErrorType mapping', () {
    test('timeout -> AppErrorType.timeout', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.receiveTimeout,
      );
      final mapped = mapDioException(e);
      expect(mapped.type, AppErrorType.timeout);
    });

    test('cancel -> AppErrorType.cancel', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.cancel,
      );
      final mapped = mapDioException(e);
      expect(mapped.type, AppErrorType.cancel);
    });

    test('badResponse 500 -> AppErrorType.server5xx', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(
            requestOptions: RequestOptions(path: '/'), statusCode: 500),
        type: DioExceptionType.badResponse,
      );
      final mapped = mapDioException(e);
      expect(mapped.type, AppErrorType.server5xx);
    });

    test('badResponse 404 -> AppErrorType.client4xx', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(
            requestOptions: RequestOptions(path: '/'), statusCode: 404),
        type: DioExceptionType.badResponse,
      );
      final mapped = mapDioException(e);
      expect(mapped.type, AppErrorType.client4xx);
    });

    test('connectionError -> AppErrorType.offline', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
        error: const SocketException('Failed host lookup'),
      );
      final mapped = mapDioException(e);
      expect(mapped.type, AppErrorType.offline);
    });

    test('SocketException in DioException.error -> AppErrorType.offline', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/'),
        error: const SocketException('Network down'),
      );
      final mapped = mapDioException(e);
      expect(mapped.type, AppErrorType.offline);
    });
  });
}
