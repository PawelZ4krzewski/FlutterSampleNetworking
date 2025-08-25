import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter_sample_networking/core/app_config.dart';
import 'package:flutter_sample_networking/core/error_types.dart';
import 'package:flutter_sample_networking/data/models/post.dart';

class ApiClient {
  final Dio _dio;

  ApiClient({Dio? dio}) : _dio = dio ?? _createDio();

  static Dio _createDio() {
    final options = BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      sendTimeout: AppConfig.sendTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      responseType: ResponseType.json,
      headers: {
        'User-Agent': 'FlutterNetBench/1.0',
        'Cache-Control': 'no-cache',
        'Accept': 'application/json',
      },
    );
    final dio = Dio(options);

    // Add noisy interceptors only outside of release to avoid perf overhead
    if (!kReleaseMode) {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          AppConfig.log('REQ -> ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          AppConfig.log('RES <- [${response.statusCode}] ${response.requestOptions.uri}');
          handler.next(response);
        },
        onError: (DioException e, handler) {
          AppConfig.log('ERR !! ${e.type} ${e.message} url=${e.requestOptions.uri}');
          handler.next(e);
        },
      ));
    }

    return dio;
  }

  /// Fetch posts from [AppConfig.baseUrl]. Expects a JSON array of objects
  /// with fields matching [Post]. Measures time and logs in ms.
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
        final response = await _dio.get('');
        final data = response.data;
        if (response.statusCode == 200 && data is List) {
          final list = data
              .map((e) => Post.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
              .cast<Post>();
          sw.stop();
          AppConfig.log('${AppConfig.timingLabelNetGet}: ${sw.elapsedMilliseconds}');
          return list;
        }
        // Unexpected body or non-200 -> treat as error
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          type: DioExceptionType.badResponse,
          message: 'Unexpected response (status=${response.statusCode})',
        );
      } on DioException catch (e) {
        sw.stop();
        AppConfig.log('${AppConfig.timingLabelNetGet}: ${sw.elapsedMilliseconds}');
        lastDioError = e;
        if (attempt + 1 < maxAttempts) {
          await Future<void>.delayed(AppConfig.retryDelay);
          attempt++;
          continue;
        }
        throw mapDioException(e);
      } on SocketException catch (e) {
        sw.stop();
        AppConfig.log('${AppConfig.timingLabelNetGet}: ${sw.elapsedMilliseconds}');
        throw AppError(type: AppErrorType.offline, message: 'No internet connection', raw: e);
      } catch (e) {
        sw.stop();
        AppConfig.log('${AppConfig.timingLabelNetGet}: ${sw.elapsedMilliseconds}');
        if (lastDioError != null) {
          throw mapDioException(lastDioError);
        }
        throw AppError(type: AppErrorType.unknown, message: e.toString(), raw: e);
      }
    }

    throw AppError(type: AppErrorType.unknown, message: 'Unknown state in fetchPosts');
  }
}
