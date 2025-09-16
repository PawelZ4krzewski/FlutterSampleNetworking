import 'dart:math';
import 'package:flutter_sample_networking/core/error_types.dart';
import 'package:flutter_sample_networking/data/api_client.dart';
import 'package:flutter_sample_networking/core/app_config.dart';

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
  AppConfig.log('BENCH_ATTEMPT: i=$i status=${r.statusCode} durationMs=${r.durationMs} error=${r.error?.type}');
    }
  final sorted = [...attempts.map((a) => a.durationMs)]..sort();
  int minMs = attempts.isEmpty ? 0 : sorted.first;
  int maxMs = attempts.isEmpty ? 0 : sorted.last;
  if (minMs > maxMs) { final t = minMs; minMs = maxMs; maxMs = t; }
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
      minMs: minMs,
      maxMs: maxMs,
      medianMs: median(),
      p95Ms: p95(),
      errorCounts: errs,
      payloadPreview: preview,
    );
  }
}

String buildCsv(BenchSummary s, Map<String, String> meta) {
  final b = StringBuffer();
  if (meta.isNotEmpty) {
    b.writeln(meta.entries.map((e) => '${e.key}=${e.value}').join(','));
  }
  b.writeln('index,status,error,durationMs');
  for (var i = 0; i < s.attempts.length; i++) {
    final a = s.attempts[i];
    b.writeln('$i,${a.status ?? ''},${a.errorType?.name ?? ''},${a.durationMs}');
  }
  return b.toString();
}

String buildMarkdown(BenchSummary s, Map<String, String> meta) {
  final b = StringBuffer();
  if (meta.isNotEmpty) {
    b.writeln('Meta:');
    for (final e in meta.entries) {
      b.writeln('- **${e.key}**: ${e.value}');
    }
    b.writeln('');
  }
  b.writeln('Summary: count=${s.count} min=${s.minMs} max=${s.maxMs} median=${s.medianMs} p95=${s.p95Ms}');
  if (s.errorCounts.isNotEmpty) {
    b.writeln('Errors: ${s.errorCounts.map((k,v)=>MapEntry(k.name,v))}');
  }
  if (s.payloadPreview.isNotEmpty) {
    b.writeln('Preview: `${s.payloadPreview}`');
  }
  b.writeln('\nAttempts:');
  b.writeln('| # | status | error | ms |');
  b.writeln('|---|--------|-------|----|');
  for (var i = 0; i < s.attempts.length; i++) {
    final a = s.attempts[i];
    b.writeln('| $i | ${a.status ?? ''} | ${a.errorType?.name ?? ''} | ${a.durationMs} |');
  }
  return b.toString();
}
