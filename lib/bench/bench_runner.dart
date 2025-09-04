import 'dart:math';
import 'package:flutter_sample_networking/core/error_types.dart';
import 'package:flutter_sample_networking/data/api_client.dart';

class BenchAttempt {
  final int? status;
  final int durationMs;
  final AppErrorType? errorType;
  const BenchAttempt({this.status, required this.durationMs, this.errorType});
}

class BenchSummary {
  final List<BenchAttempt> attempts;
  final int count, minMs, maxMs, medianMs, p95Ms;
  final Map<AppErrorType, int> errorCounts;
  final String payloadPreview;
  const BenchSummary({
    required this.attempts,
    required this.count,
    required this.minMs,
    required this.maxMs,
    required this.medianMs,
    required this.p95Ms,
    required this.errorCounts,
    required this.payloadPreview,
  });
}

class BenchRunner {
  Future<BenchSummary> run({
    required ApiClient client,
    String path = '/posts',
    required int runs,
    bool warmup = true,
    Duration? connectTimeout,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool? enableRetryOverride,
  }) async {
    final attempts = <BenchAttempt>[];
    String preview = '';
    for (var i = 0; i < runs; i++) {
      final r = await client.fetchPostsWithMetrics(
        path: path,
        connectTimeout: connectTimeout,
        sendTimeout: sendTimeout,
        receiveTimeout: receiveTimeout,
        enableRetryOverride: enableRetryOverride,
      );
      // warm-up discard
      final isWarmup = warmup && i == 0;
      if (r.isSuccess) {
        final list = r.data!;
        if (preview.isEmpty && list.isNotEmpty) {
          final p = list.first;
          preview = '${p.title} | ${p.body}'
              .substring(0, min(200, ('${p.title} | ${p.body}').length));
        }
        if (!isWarmup) {
          attempts.add(
              BenchAttempt(status: r.statusCode, durationMs: r.durationMs));
        }
      } else {
        if (!isWarmup) {
          attempts.add(BenchAttempt(
            status: r.statusCode,
            durationMs: r.durationMs,
            errorType: r.error?.type,
          ));
        }
      }
    }
    final sorted = [...attempts.map((a) => a.durationMs)]..sort();
    int median() {
      final n = sorted.length;
      if (n == 0) return 0;
      return n.isOdd
          ? sorted[n ~/ 2]
          : ((sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) ~/ 2);
    }

    int p95() {
      final n = sorted.length;
      if (n == 0) return 0;
      final idx = (0.95 * (n - 1)).floor().clamp(0, n - 1);
      return sorted[idx];
    }

    final errs = <AppErrorType, int>{};
    for (final a in attempts) {
      if (a.errorType != null) {
        errs.update(a.errorType!, (v) => v + 1, ifAbsent: () => 1);
      }
    }
    return BenchSummary(
      attempts: attempts,
      count: attempts.length,
      minMs: attempts.isEmpty ? 0 : sorted.first,
      maxMs: attempts.isEmpty ? 0 : sorted.last,
      medianMs: median(),
      p95Ms: p95(),
      errorCounts: errs,
      payloadPreview: preview,
    );
  }
}
