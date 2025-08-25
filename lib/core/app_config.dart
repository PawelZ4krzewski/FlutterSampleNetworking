// No external imports; config uses compile-time environment values.

/// Centralized, deterministic app configuration sourced from --dart-define.
///
/// Example (profile run):
/// flutter run --profile \
///   --dart-define=BASE_URL=https://jsonplaceholder.typicode.com/posts \
///   --dart-define=CONNECT_TIMEOUT_MS=8000 \
///   --dart-define=SEND_TIMEOUT_MS=8000 \
///   --dart-define=RECEIVE_TIMEOUT_MS=8000
class AppConfig {
  AppConfig._();

  /// Canonical timing log label used across the app for network GET.
  static const String timingLabelNetGet = 'NET_GET_MS';

  /// Base URL from environment; enforces explicit --dart-define during perf runs.
  static const String baseUrl = String.fromEnvironment('BASE_URL', defaultValue: 'WSTAW_URL');

  /// Timeouts (ms) from environment; defaults 8000.
  static const int connectTimeoutMs =
      int.fromEnvironment('CONNECT_TIMEOUT_MS', defaultValue: 8000);
  static const int sendTimeoutMs =
      int.fromEnvironment('SEND_TIMEOUT_MS', defaultValue: 8000);
  static const int receiveTimeoutMs =
      int.fromEnvironment('RECEIVE_TIMEOUT_MS', defaultValue: 8000);

  static const Duration connectTimeout =
      Duration(milliseconds: connectTimeoutMs);
  static const Duration sendTimeout = Duration(milliseconds: sendTimeoutMs);
  static const Duration receiveTimeout =
      Duration(milliseconds: receiveTimeoutMs);

  /// Retry disabled by default for perf runs; can be toggled via build flavors
  /// by injecting a different constant at compile-time if needed.
  static const bool enableRetry =
      bool.fromEnvironment('ENABLE_RETRY', defaultValue: false);
  static const int retryMaxAttempts = 2; // initial + 1 retry
  static const Duration retryDelay = Duration(milliseconds: 500);

  /// Simple logger; in release this still prints to platform logs.
  static void log(Object? message) {
    // ignore: avoid_print
    print('[App] $message');
  }
}
