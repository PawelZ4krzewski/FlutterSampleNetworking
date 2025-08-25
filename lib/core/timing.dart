import 'package:flutter/foundation.dart';
import 'package:flutter_sample_networking/core/app_config.dart';

/// Simple timing helpers based on Stopwatch.
Stopwatch startTimer() => Stopwatch()..start();

void logDuration(String label, Stopwatch sw) {
  sw.stop();
  final ms = sw.elapsedMilliseconds;
  if (kDebugMode) {
    // ignore: avoid_print
    print('[Timing] $label took ${ms}ms');
  }
  AppConfig.log('TIMING $label: ${ms}ms');
}
