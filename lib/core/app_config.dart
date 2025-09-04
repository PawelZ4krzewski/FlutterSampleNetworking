class AppConfig {
  AppConfig._();
  static const String timingLabelNetGet = 'NET_GET_MS';
  static const String baseUrl =
      String.fromEnvironment('BASE_URL', defaultValue: 'WSTAW_URL');
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

  static const bool enableRetry =
      bool.fromEnvironment('ENABLE_RETRY', defaultValue: false);
  static const int retryMaxAttempts = 2; // initial + 1 retry
  static const Duration retryDelay = Duration(milliseconds: 500);
  static void log(Object? message) {
    // ignore: avoid_print
    print('[App] $message');
  }
}
