import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sample_networking/bench/bench_runner.dart';
import 'package:flutter_sample_networking/data/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_sample_networking/core/error_types.dart';
import 'package:flutter_sample_networking/data/models/post.dart';

class FakeApiClient extends ApiClient {
  final List<NetResponse<List<Post>>> scripted;
  int _i = 0;
  FakeApiClient(this.scripted)
      : super(
          dio: Dio(BaseOptions(baseUrl: 'https://example.com')),
        );

  @override
  Future<NetResponse<List<Post>>> fetchPostsWithMetrics({
    String path = '/posts',
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool? enableRetryOverride,
  }) async {
    if (_i >= scripted.length) return scripted.last;
    return scripted[_i++];
  }
}

NetResponse<List<Post>> success(int ms) => NetResponse<List<Post>>(
      data: const <Post>[],
      statusCode: 200,
      durationMs: ms,
    );

NetResponse<List<Post>> failure(int ms, AppErrorType t) => NetResponse<List<Post>>(
      error: AppError(type: t, message: t.name),
      statusCode: null,
      durationMs: ms,
    );

void main() {
  group('BenchRunner', () {
    test('warm-up discard and median calculation (even count)', () async {
      final api = FakeApiClient([
        success(10), // warm-up (discarded)
        success(20),
        success(30),
        success(40),
        success(50),
      ]);
      final runner = BenchRunner();
      final summary = await runner.run(client: api, runs: 5, warmup: true);
      expect(summary.count, 4);
      expect(summary.minMs, 20);
      expect(summary.maxMs, 50);
      expect(summary.medianMs, 35); // (30 + 40)/2
    });

    test('p95 calculation', () async {
      final scripted = <NetResponse<List<Post>>>[];
      final durations = [5,10,15,20,25,30,35,40,45,50];
      for (final d in durations) {
        scripted.add(success(d));
      }
      final api = FakeApiClient(scripted);
      final summary = await BenchRunner().run(client: api, runs: durations.length, warmup: false);
      expect(summary.count, 10);
      expect(summary.p95Ms, 45); // index floor(0.95*(n-1)) = 8
    });

    test('error counts aggregation', () async {
      final api = FakeApiClient([
        failure(12, AppErrorType.offline),
        failure(13, AppErrorType.timeout),
        failure(14, AppErrorType.timeout),
        success(15),
      ]);
      final summary = await BenchRunner().run(client: api, runs: 4, warmup: false);
      expect(summary.count, 4);
      expect(summary.errorCounts[AppErrorType.offline], 1);
      expect(summary.errorCounts[AppErrorType.timeout], 2);
    });

    test('all attempts discarded when only warm-up', () async {
      final api = FakeApiClient([success(9)]);
      final summary = await BenchRunner().run(client: api, runs: 1, warmup: true);
      expect(summary.count, 0);
      expect(summary.minMs, 0);
      expect(summary.maxMs, 0);
      expect(summary.medianMs, 0);
      expect(summary.p95Ms, 0);
    });
  });
}
