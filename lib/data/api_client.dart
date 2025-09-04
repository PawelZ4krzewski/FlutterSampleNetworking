import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_sample_networking/core/app_config.dart';
import 'package:flutter_sample_networking/core/error_types.dart';
import 'package:flutter_sample_networking/data/models/post.dart';

class NetResponse<T> {
  final T? data;
  final AppError? error;
  final int? statusCode;
  final int durationMs;
  const NetResponse(
      {this.data, this.error, this.statusCode, required this.durationMs});
  bool get isSuccess => data != null && error == null;
}

class ApiClient {
  final Dio _dio;

  ApiClient({Dio? dio}) : _dio = dio ?? _createDio();

  ApiClient.withBaseUrl(String baseUrl) : _dio = _createDioWithBaseUrl(baseUrl);

  static Dio _createDio() {
    return _createDioWithBaseUrl(AppConfig.baseUrl);
  }

  static Dio _createDioWithBaseUrl(String baseUrl) {
    final options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      sendTimeout: AppConfig.sendTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      responseType: ResponseType.json,
      headers: {
        'User-Agent': 'NetBench/1.0',
        'Cache-Control': 'no-cache',
        'Accept': 'application/json',
      },
    );
    final dio = Dio(options);

    if (!kReleaseMode) {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          AppConfig.log('REQ -> ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          AppConfig.log(
              'RES <- [${response.statusCode}] ${response.requestOptions.uri}');
          handler.next(response);
        },
        onError: (DioException e, handler) {
          AppConfig.log(
              'ERR !! ${e.type} ${e.message} url=${e.requestOptions.uri}');
          handler.next(e);
        },
      ));
    }

    return dio;
  }

  Future<List<Post>> fetchPosts() async {
    if (AppConfig.baseUrl == 'WSTAW_URL' || AppConfig.baseUrl.isEmpty) {
      throw StateError('Please set AppConfig.baseUrl to a valid endpoint URL.');
    }

    final maxAttempts = AppConfig.enableRetry ? AppConfig.retryMaxAttempts : 1;
    int attempt = 0;
    DioException? lastDioError;

    while (attempt < maxAttempts) {
      final sw = Stopwatch()..start();
      try {
        final response = await _dio.get('/posts');
        final data = response.data;
        if (response.statusCode == 200 && data is List) {
          final list = data
              .map((e) => Post.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
              .cast<Post>();
          sw.stop();
          AppConfig.log(
              '${AppConfig.timingLabelNetGet}: ${sw.elapsedMilliseconds}');
          return list;
        }
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Unexpected response (status=${response.statusCode})',
        );
      } on DioException catch (e) {
        sw.stop();
        AppConfig.log(
            '${AppConfig.timingLabelNetGet}: ${sw.elapsedMilliseconds}');
        lastDioError = e;
        if (attempt + 1 < maxAttempts) {
          await Future<void>.delayed(AppConfig.retryDelay);
          attempt++;
          continue;
        }
        throw mapDioException(e);
      } on SocketException catch (e) {
        sw.stop();
        AppConfig.log(
            '${AppConfig.timingLabelNetGet}: ${sw.elapsedMilliseconds}');
        throw AppError(
            type: AppErrorType.offline,
            message: 'No internet connection',
            raw: e);
      } catch (e) {
        sw.stop();
        AppConfig.log(
            '${AppConfig.timingLabelNetGet}: ${sw.elapsedMilliseconds}');
        if (lastDioError != null) {
          throw mapDioException(lastDioError);
        }
        throw AppError(
            type: AppErrorType.unknown, message: e.toString(), raw: e);
      }
    }

  throw AppError(type: AppErrorType.unknown, message: 'Unknown state in fetchPosts');
  }

  Future<NetResponse<List<Post>>> fetchPostsWithMetrics({
    String path = '/posts',
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool? enableRetryOverride,
  }) async {
    if (AppConfig.baseUrl == 'WSTAW_URL' || AppConfig.baseUrl.isEmpty) {
      throw StateError('Please set AppConfig.baseUrl to a valid endpoint URL.');
    }

    // Build a fresh Dio if any override is provided; otherwise use existing one
    final dio = (connectTimeout != null ||
            sendTimeout != null ||
            receiveTimeout != null)
        ? Dio(BaseOptions(
            baseUrl: AppConfig.baseUrl,
            connectTimeout: connectTimeout ?? AppConfig.connectTimeout,
            sendTimeout: sendTimeout ?? AppConfig.sendTimeout,
            receiveTimeout: receiveTimeout ?? AppConfig.receiveTimeout,
            responseType: ResponseType.json,
            headers: {
              'User-Agent': 'NetBench/1.0',
              'Cache-Control': 'no-cache',
              'Accept': 'application/json',
            },
          ))
        : _dio;

    final sw = Stopwatch()..start();
    try {
      final response = await dio.get(path);
      final data = response.data;
      if (response.statusCode == 200 && data is List) {
        final posts = data
            .map((e) => Post.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
            .cast<Post>();
        sw.stop();
        AppConfig.log('NET_GET_MS: ${sw.elapsedMilliseconds}');
        return NetResponse<List<Post>>(
          data: posts,
          statusCode: response.statusCode,
          durationMs: sw.elapsedMilliseconds,
        );
      }
      sw.stop();
      AppConfig.log('NET_GET_MS: ${sw.elapsedMilliseconds}');
      final mapped = mapDioException(DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Unexpected response (status=${response.statusCode})',
      ));
      return NetResponse<List<Post>>(
        error: mapped,
        statusCode: response.statusCode,
        durationMs: sw.elapsedMilliseconds,
      );
    } on DioException catch (e) {
      sw.stop();
      AppConfig.log('NET_GET_MS: ${sw.elapsedMilliseconds}');
      final mapped = mapDioException(e);
      return NetResponse<List<Post>>(
        error: mapped,
        statusCode: e.response?.statusCode,
        durationMs: sw.elapsedMilliseconds,
      );
    } on SocketException catch (e) {
      sw.stop();
      AppConfig.log('NET_GET_MS: ${sw.elapsedMilliseconds}');
      return NetResponse<List<Post>>(
        error: AppError(
            type: AppErrorType.offline,
            message: 'No internet connection',
            raw: e),
        durationMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();
      AppConfig.log('NET_GET_MS: ${sw.elapsedMilliseconds}');
      return NetResponse<List<Post>>(
        error:
            AppError(type: AppErrorType.unknown, message: e.toString(), raw: e),
        durationMs: sw.elapsedMilliseconds,
      );
    }
  }
}
