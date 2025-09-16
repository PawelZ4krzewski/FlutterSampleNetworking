# Project Snapshot

- Package name: `flutter_sample_networking` (pubspec.yaml)
- Version: 0.1.0 (pubspec.yaml)
- Dart SDK constraint: `>=3.3.0 <4.0.0` (pubspec.yaml)
- Module layout (lib/):
  - `core/` (app_config.dart, error_types.dart, timing.dart)
  - `data/` (api_client.dart, models/post.dart)
  - `domain/` (repository.dart)
  - `ui/` (screens: data_screen.dart, bench_screen.dart; widgets/error_view.dart)
  - `bench/` (bench_runner.dart)
- Tooling versions: Flutter version not pinned in repo (README mentions Flutter 3.3+). No .metadata or version pin present. => Flutter SDK version: UNKNOWN (run `flutter --version` locally to record exact hash); documented minimum 3.3+ (README.md)
- Networking library: dio ^5.4.0 (pubspec.yaml)
- JSON: manual mapping (`Post.fromJson`, no codegen) (lib/data/models/post.dart)
- Test libs: flutter_test (pubspec.yaml)
- Lints: flutter_lints ^5.0.0 (pubspec.yaml)
- Target platforms (implicit via standard Flutter project structure): Android, iOS, plus desktop/web folders exist (macos/, linux/, windows/, web/)

# Networking Stack Overview

- HTTP client: Dio (import 'package:dio/dio.dart') in `lib/data/api_client.dart`.
- Interceptors: Added only in non-release mode (`if (!kReleaseMode) { dio.interceptors.add(...) }`). They log request, response, error.
- JSON decoding: Manual mapping with `Post.fromJson(Map<String,dynamic>)` (no build_runner / json_serializable present).
- Logging: `AppConfig.log()` prints with prefix `[App]`. Timing logs: `NET_GET_MS: <ms>` emitted in `ApiClient.fetchPosts()` and `fetchPostsWithMetrics()` after Stopwatch stop.
- Default headers set in `BaseOptions.headers`: `User-Agent: NetBench/1.0`, `Cache-Control: no-cache`, `Accept: application/json` (api_client.dart).
- Timeouts: connect/send/receive set via `AppConfig.connectTimeout`, `AppConfig.sendTimeout`, `AppConfig.receiveTimeout` passed into BaseOptions; override possible per bench run constructing fresh Dio when any override provided.

# Configuration & Runtime Flags

AppConfig fields (lib/core/app_config.dart):
- `timingLabelNetGet = 'NET_GET_MS'`
- `baseUrl`: from `--dart-define=BASE_URL` default 'WSTAW_URL'
- `connectTimeoutMs`: from `CONNECT_TIMEOUT_MS` default 8000
- `sendTimeoutMs`: from `SEND_TIMEOUT_MS` default 8000
- `receiveTimeoutMs`: from `RECEIVE_TIMEOUT_MS` default 8000
- `connectTimeout`, `sendTimeout`, `receiveTimeout`: Durations wrapping ms values
- `enableRetry`: from `ENABLE_RETRY` default false
- `retryMaxAttempts = 2`
- `retryDelay = 500ms`
- `log(Object? message)` simple print wrapper

Flags supplied via `--dart-define` (README & code). BASE_URL must be set to non-placeholder for real operation.

Code excerpt (app_config.dart):
```dart
static const String baseUrl = String.fromEnvironment('BASE_URL', defaultValue: 'WSTAW_URL');
static const int connectTimeoutMs = int.fromEnvironment('CONNECT_TIMEOUT_MS', defaultValue: 8000);
static const bool enableRetry = bool.fromEnvironment('ENABLE_RETRY', defaultValue: false);
```

# Request Flow (Step-by-Step)

1. UI: `DataScreen` initiates `_load()` (lib/ui/screens/data_screen.dart) calling `Repository.getPosts()`.
2. Repository (`lib/domain/repository.dart`) calls `_client.fetchPosts()`.
3. ApiClient (`lib/data/api_client.dart`) executes Dio `get('/posts')` using configured BaseOptions.
4. Stopwatch started per attempt; after response or error it's stopped; log `NET_GET_MS: <ms>`.
5. On success (status 200 & JSON List) decode each element to `Post` via `Post.fromJson`.
6. On unexpected body / non-200, create DioException and map to AppError (if thrown path) or wrap in NetResponse in metrics variant.
7. Errors mapped by `mapDioException` producing `AppError` with AppErrorType.
8. Repository converts to `Result.success` or `Result.failure`.
9. UI updates state accordingly (loading spinner → list or error view).

Bench flow:
1. `BenchScreen` collects inputs (BASE_URL override, path, N, timeouts, retry toggle) and invokes `BenchRunner.run()`.
2. `BenchRunner` loops N times, discards first if warm-up, calls `ApiClient.fetchPostsWithMetrics()`.
3. Each call logs `NET_GET_MS` from data layer only, returns `NetResponse` with `durationMs`.
4. Bench aggregates median & p95, counts errors, builds preview.

Retry: In `fetchPosts()` attempts loop uses `AppConfig.enableRetry`; maxAttempts = 2 when enabled; delay 500ms. Default OFF (false) for perf parity. Metrics variant currently ignores `enableRetryOverride` (TODO: wire flag for symmetry or document intentional exclusion to avoid distorting timing).

# Error Taxonomy

Mapping function: `mapDioException` in `lib/core/error_types.dart`.

Table:
| Type | Conditions | Mapped From |
|------|------------|-------------|
| offline | `DioExceptionType.connectionError` OR `e.error is SocketException` | Connection error / SocketException |
| timeout | `DioExceptionType.connectionTimeout`, `sendTimeout`, `receiveTimeout` | Timeout types |
| client4xx | `badResponse` AND 400 <= status < 500 | HTTP 4xx |
| server5xx | `badResponse` AND status >= 500 | HTTP 5xx |
| cancel | `DioExceptionType.cancel` | Cancelled request |
| unknown | Else branch | Any other |

Excerpt (error_types.dart):
```dart
if (e.type == DioExceptionType.connectionTimeout ||
    e.type == DioExceptionType.sendTimeout ||
    e.type == DioExceptionType.receiveTimeout) {
  return AppError(type: AppErrorType.timeout, message: 'Request timed out', raw: e);
}
if (e.type == DioExceptionType.badResponse) {
  if (status != null && status >= 500) { ... }
  if (status != null && status >= 400 && status < 500) { ... }
}
if (e.type == DioExceptionType.cancel) { ... }
if (e.type == DioExceptionType.connectionError || e.error is SocketException) { ... }
return AppError(type: AppErrorType.unknown, message: 'Unknown error', raw: e, statusCode: status);
```

# Timeouts & Headers

Timeout table:
| Kind | Default (ms) | Where defined | Override Mechanism |
|------|--------------|---------------|--------------------|
| Connect | 8000 | app_config.dart (connectTimeoutMs) -> api_client.dart BaseOptions | --dart-define CONNECT_TIMEOUT_MS; Bench: per-call override creates new Dio |
| Send | 8000 | app_config.dart (sendTimeoutMs) -> BaseOptions | --dart-define SEND_TIMEOUT_MS; Bench override |
| Receive | 8000 | app_config.dart (receiveTimeoutMs) -> BaseOptions | --dart-define RECEIVE_TIMEOUT_MS; Bench override |

Header table (api_client.dart):
| Header | Value | Location |
|--------|-------|----------|
| User-Agent | NetBench/1.0 | BaseOptions.headers (api_client.dart) |
| Cache-Control | no-cache | BaseOptions.headers (api_client.dart) |
| Accept | application/json | BaseOptions.headers (api_client.dart) |

No duplicate timeout configuration found (only BaseOptions, no per-request overrides except new Dio in metrics path).
Confirmation: Timeouts are defined once in `BaseOptions` (no interceptor mutation). Excerpt:
```dart
final options = BaseOptions(
  baseUrl: baseUrl,
  connectTimeout: AppConfig.connectTimeout,
  sendTimeout: AppConfig.sendTimeout,
  receiveTimeout: AppConfig.receiveTimeout,
  headers: { 'User-Agent': 'NetBench/1.0','Cache-Control': 'no-cache','Accept': 'application/json', },
);
```

# Data Models & JSON

Models:
- `Post` (fields: id, title, body) (lib/data/models/post.dart)

Excerpt:
```dart
class Post {
  final int id;
  final String title;
  final String body;
  const Post({required this.id, required this.title, required this.body});
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: (json['id'] is String)
          ? int.tryParse(json['id'] as String) ?? 0
          : (json['id'] ?? 0) as int,
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
    );
  }
  Map<String, dynamic> toJson() => { 'id': id, 'title': title, 'body': body };
}
```

Guards: handles id as String or int; defaults missing to 0 / empty strings.

# Key Source Files (with excerpts)

`lib/core/app_config.dart`:
- Provides environment-sourced constants (BASE_URL, timeouts, retry).
```dart
static const bool enableRetry = bool.fromEnvironment('ENABLE_RETRY', defaultValue: false);
static const int retryMaxAttempts = 2;
static const Duration retryDelay = Duration(milliseconds: 500);
```

`lib/core/error_types.dart`:
- Error mapping and taxonomy.
```dart
enum AppErrorType { offline, timeout, client4xx, server5xx, cancel, unknown }
AppError mapDioException(DioException e) { ... }
```

`lib/core/timing.dart`:
- Stopwatch helper (not central to network logs; main timing in ApiClient).
```dart
Stopwatch startTimer() => Stopwatch()..start();
```

`lib/data/api_client.dart`:
- Dio client config, headers, timeouts, retry loop, timing log, metrics wrapper.
```dart
final response = await _dio.get('/posts');
AppConfig.log('${AppConfig.timingLabelNetGet}: ${sw.elapsedMilliseconds}');
return list;
```
Metrics variant:
```dart
final response = await dio.get(path);
AppConfig.log('NET_GET_MS: ${sw.elapsedMilliseconds}');
return NetResponse<List<Post>>(...);
```

`lib/domain/repository.dart`:
- Wraps ApiClient result into `Result`.
```dart
final list = await _client.fetchPosts();
return Result.success(list);
```

`lib/ui/screens/data_screen.dart`:
- Loads posts, manages loading/error/list UI.
```dart
final result = await _repository.getPosts();
if (result.isSuccess) { _items = result.data!; } else { _error = result.error; }
```

`lib/ui/screens/bench_screen.dart`:
- Inputs (baseUrl, path, runs, warmup, timeouts, retry) and results list & aggregates.
```dart
final customApiClient = ApiClient.withBaseUrl(baseUrl);
final result = await runner.run(...);
Text('Median: ${_lastResult!.medianMs}ms');
```

`lib/bench/bench_runner.dart`:
- Executes N requests; computes median & p95.
```dart
final idx = (0.95 * (n - 1)).floor().clamp(0, n - 1);
return sorted[idx];
```

# Bench UI & Metrics

Inputs present: BASE_URL override, PATH, Runs (N), Warm-up (checkbox), Connect/Send/Receive timeouts, Enable retry (switch). Source: `bench_screen.dart`.
Outputs: attempts list (duration, status/errorType), aggregates (count/min/max/median/p95), error counts, payload preview (first Post truncated to <=200 chars). Source: `bench_runner.dart`.
Timing: UI does not measure; durations from `NetResponse.durationMs` (ApiClient Stopwatch). Only data layer logs `NET_GET_MS`.
P95 formula: `floor(0.95 * (n - 1))` (bench_runner.dart).

# Tests

Test files:
- `test/unit/error_mapping_test.dart`: verifies mapping for timeout, cancel, 500->server5xx, 404->client4xx, connectionError/offline, SocketException->offline.
- `test/unit/model_decode_test.dart`: verifies Post JSON decoding.
No integration tests, no HTTP mocking adapters (e.g., http_mock_adapter) present. No widget tests around networking UI.
Mocks: None; tests construct DioException directly.

# Build Types & Release Notes

Profile run example (README):
```bash
flutter run --profile \
  --dart-define=BASE_URL=https://jsonplaceholder.typicode.com \
  --dart-define=CONNECT_TIMEOUT_MS=8000 \
  --dart-define=SEND_TIMEOUT_MS=8000 \
  --dart-define=RECEIVE_TIMEOUT_MS=8000
```
Build commands (README): `flutter build apk --release`, `flutter build appbundle --release`, `flutter build ios --release`.
Size measurement scripts mentioned in README (scripts folder referenced, actual script contents not shown here; assumption: present). Logging minimized in release (interceptors skipped due to `if (!kReleaseMode)`). No explicit obfuscation flags in README except suggestion for minified variant (`--obfuscate --split-debug-info=...`).
Scripts (present):
- `scripts/build_size_android.sh` -> writes `metrics/build_size_apk.txt`, `metrics/build_size_aab.txt`
- `scripts/build_size_ios.sh` -> writes `metrics/build_size_ipa.txt`
- `scripts/loc_flutter.sh` -> writes `metrics/loc_flutter.txt`
- `scripts/parse_net_logs_to_csv.sh` -> appends NET_GET_MS lines to `metrics/results_YYYYMMDD.csv`

Example data-layer log lines (captured during runs):
```
[App] NET_GET_MS: 316
[App] NET_GET_MS: 101
[App] NET_GET_MS: 109
```
Sample bench aggregation (illustrative from BenchScreen UI state):
```
count=19 min=87ms max=241ms median=109ms p95=233ms errors={} preview="sunt aut facere..."
```

Profile / Release guidance:
```bash
# Profile (deterministic, retry off)
flutter run --profile --dart-define=BASE_URL=https://jsonplaceholder.typicode.com

# Release APK (baseline)
flutter build apk --release
# Minified / size study
flutter build apk --release --split-debug-info=build/symbols --obfuscate --split-per-abi
flutter build appbundle --release --split-debug-info=build/symbols --obfuscate
```
Ensure: set explicit BASE_URL; keep ENABLE_RETRY=false for timing fairness.

# Known Limitations & TODO

- Placeholder BASE_URL default 'WSTAW_URL' requires explicit define.
- Retry override parameter (`enableRetryOverride`) in metrics method not applied internally (INFERRED improvement: pass through to logic / replicate retry loop).
- No caching layer; every request uncached.
- No cancellation support exposed in Repository/UI.
- No structured logging system (raw print).
- No TLS pinning / certificate validation customization.
- No integration tests; only unit-level error mapping & model decode.
- Bench screen uses fixed 300px list height (potential UX limitation).

# Appendix: Dependency Versions

| Package | Version | Source |
|---------|---------|--------|
| flutter | SDK (unversioned in pubspec, min Flutter 3.3+ in README) | pubspec.yaml / README.md |
| dio | ^5.4.0 | pubspec.yaml |
| flutter_test | SDK | pubspec.yaml |
| flutter_lints | ^5.0.0 | pubspec.yaml |

Flutter SDK version exact: UNKNOWN (not pinned).
No other networking/JSON libs present.


## Benchmark Scenarios (S1–S6)

Exact reflection of `lib/bench/bench_presets.dart` (single source of truth). Timeouts listed as connect/send/receive.

| ID | Title | BASE_URL | PATH | Timeouts (ms) | Retry | Note |
|----|-------|----------|------|---------------|-------|------|
| S1 | S1 Small | https://dummyjson.com | /posts/1 | 8000/8000/8000 | OFF | Latency single small payload |
| S2 | S2 List | https://dummyjson.com | /posts?limit=100 | 8000/8000/8000 | OFF | List parsing |
| S3 | S3 Error | https://httpbingo.org | /status/500 | 8000/8000/8000 | OFF | Deterministic 500 |
| S4 | S4 Timeout | https://httpbingo.org | /delay/10 | 1000/1000/1000 | OFF | 200 delayed -> timeout |
| S5 | S5 Offline | https://dummyjson.com | /posts/1 | 8000/8000/8000 | OFF | Enable airplane mode |
| S6 | S6 Headers | https://httpbingo.org | /headers | 8000/8000/8000 | OFF | Echo headers (httpbin) |

Warm-up: discard first attempt when enabled (bench UI checkbox). Effective sample size with N=30 is 29.

## Measurement Configuration (parity)

- Dio BaseOptions headers: User-Agent=NetBench/1.0, Cache-Control=no-cache, Accept=application/json
- Timeouts: connect/send/receive configured via BaseOptions (environment overrides)
- One Dio instance per logical run; single Stopwatch timing per request; log key: `NET_GET_MS`
- Warm-up: ON (discard first); N=30 → 29 samples analyzed
- Build mode: Profile / Release (no debug HTTP interceptor noise)
- Retry: OFF (fair latency comparison)
- Error taxonomy: Timeout, NoInternet (SocketException/connectionError), Http4xx, Http5xx, Cancel, Unknown (see `mapDioException`)
- P95 index: `floor(0.95 * (n - 1))`

## Recent Changes (2025-09-05)

- Presets: S3 → `/status/500` on httpbingo; S4 → `/delay/10` on httpbingo (1s client timeouts); S6 → `/headers`
- Enhanced `mapDioException`: classify connectionError with timeout wording as Timeout; 4xx / 5xx via badResponse
- Guard: non-2xx responses not decoded; thrown and mapped
- Added diagnostic log line: `DIO_ERR type=... status=... rt=... msg=...`
- Preserved single per-request timing log `NET_GET_MS`
- Aggregate guard ensuring `min <= max`
- Ensured one Dio per benchmark series

## Tests (what exists & how to run)

Existing unit tests (see `test/unit/`):
- `bench_runner_test.dart` – median, p95, warm-up discard, error aggregation
- `error_mapping_test.dart` – DioException → AppErrorType mapping (timeout, cancel, 4xx, 5xx, offline)
- `model_decode_test.dart` – Post JSON decoding variants

Run locally (all tests):
```
flutter test
```
With coverage (generates `coverage/lcov.info`):
```
flutter test --coverage
```

Integration HTTP tests: intentionally omitted (public endpoints + focus on app-layer timing). Could be added with e.g. `http_mock_adapter` for deterministic responses – out of current scope.

Manual bench procedure:
1. Open Bench screen.
2. Choose preset (S1–S6) OR custom baseUrl+path.
3. Set N=30, Warm-up ON (discard 1st automatically).
4. Run scenario or Run All.
5. After completion: capture CSV / Markdown via buttons or log batch CSV.
6. Use single `NET_GET_MS` lines from logs for external validation.

## Environment for Reproducibility

Tooling versions (derive & record before publication):
- Flutter SDK: (to-fill: output of `flutter --version` e.g. Flutter 3.x.x • channel stable • revision <hash>)
- Dart SDK: (paired with Flutter above)
- Android Gradle Plugin: (to-fill if needed; gradle wrapper present)
- Gradle Wrapper: see `android/gradle/wrapper/gradle-wrapper.properties` (to-fill distributionUrl)
- Xcode: (to-fill: e.g. 15.x)

Dependencies (from `pubspec.lock`):
- dio 5.9.0 (declared ^5.4.0 in pubspec, resolved 5.9.0)
- flutter_lints 5.0.0
- test_api 0.7.4 (transitive)
- collection 1.19.1 (transitive key for list ops)
- vm_service 15.0.0 (transitive, dev tooling)

SDK constraints:
- Dart >=3.3.0 <4.0.0 (pubspec) ; lockfile indicates min >=3.7.0-0 pre for some deps (stable usage expected)

Runtime environments (document actual devices):
- Android: (to-fill: Device model, SoC, API level, build variant=profile/release)
- iOS: (to-fill: Simulator model e.g. iPhone 15, iOS version, or physical device)

Execution conditions:
- Same Wi-Fi network; minimal background traffic
- Build mode: Profile (preferred) or Release
- Interceptors disabled in Release (kReleaseMode)
- Retry OFF
- N=30, discard 1 (warm-up) → 29 analyzed
- One Dio instance per series
- Identical headers & timeout values across platforms
- Airplane mode only for S5 Offline

## Parity Checklist (Flutter vs Compose)

- Headers identical: User-Agent=NetBench/1.0, Cache-Control=no-cache, Accept=application/json
- Timeouts: S1/S2/S6 8000/8000/8000 ms; S4 1000/1000/1000 ms; S3/S5 also 8000/8000/8000
- Retry: OFF for measurements
- Single Dio client per benchmark series (fresh for overrides)
- Exactly one Stopwatch + one `NET_GET_MS` log per request
- P95 index = floor(0.95*(n-1)) on sorted durations
- Endpoints: dummyjson (S1,S2), httpbingo `/status/500` (S3), httpbingo `/delay/10` (S4), dummyjson (S5 baseline but offline), httpbingo `/headers` (S6)
- Warm-up discard: first attempt excluded when enabled

## Exact Commands (Build / Run / Bench)

Static analysis:
```
flutter analyze
```

Unit tests:
```
flutter test
flutter test --coverage
```

Profile run (default timeouts 8000ms):
```
flutter run --profile \
  --dart-define=BASE_URL=https://dummyjson.com \
  --dart-define=CONNECT_TIMEOUT_MS=8000 \
  --dart-define=SEND_TIMEOUT_MS=8000 \
  --dart-define=RECEIVE_TIMEOUT_MS=8000
```

Timeout scenario S4 (1s client timeouts):
```
flutter run --profile \
  --dart-define=BASE_URL=https://httpbingo.org \
  --dart-define=CONNECT_TIMEOUT_MS=1000 \
  --dart-define=SEND_TIMEOUT_MS=1000 \
  --dart-define=RECEIVE_TIMEOUT_MS=1000
```

Release build (Android APK):
```
flutter build apk --release
```

Bench screen usage:
1. Select preset (e.g. S2 List) – fields auto-populate
2. Set Runs=N=30, enable Warm-up
3. Press Run Scenario or Run All
4. After completion: Copy CSV / Copy MD (or Log Batch CSV) for archival
5. Clear Batch Results when starting a new series

## Dependencies & Versions (pin)

Primary:
- dio 5.9.0 – HTTP client (timeouts & headers via BaseOptions)

Dev / Quality:
- flutter_lints 5.0.0 – lint rules
- flutter_test (SDK) – test framework

Not used: code generation (no json_serializable), caching libs, logging frameworks (raw print only), mock adapters.

## Payload Notes

- S1 Small: Single post object (few string fields) – minimal parse cost
- S2 List: ~100 post objects – stresses JSON decode & allocation
- S3 Error: 500 status body ignored (no decode) – measures error path overhead
- S4 Timeout: No body (client abort) – captures timeout latency (client threshold + overhead)
- S5 Offline: Immediate socket/connection error – fail-fast path (<50ms expected on real device)
- S6 Headers: Echo headers JSON; keys may vary; client reads subset (current code normalizes as needed in metrics path)

## Latest Results (Flutter, 2025-09-05)

```
scenario,N,median_ms,p95_ms,min_ms,max_ms,errors
S1 Small,29,310,406,280,414,0
S2 List,29,523,620,321,681,0
S3 Error,29,216,305,199,310,29
S4 Timeout,29,1105,1132,1071,1135,29
S5 Offline,29,16,19,14,23,29
S6 Headers,29,303,364,204,544,0
```

## Interpretation Highlights

- S1 / S2: Low medians; Flutter ahead vs expected Compose baseline (lower = better)
- S3: Deterministic 500 classification; error path latency stable
- S4: ~1s + minor overhead indicates timeout trigger behaving as configured
- S5: Fail-fast offline path (<20ms observed) – minimal stack overhead
- S6: Median similar class to S1; higher P95 influenced by endpoint variability
- Error scenarios (S3,S4,S5) measure cost of failure handling, not payload decode

## Threats to Validity

- Public endpoints → tail latency variance (repeat 2–3 series; compare medians & P95)
- Device thermal / CPU scaling can skew longer runs → document temperature / battery state
- Network contention (other traffic) may inflate tail; isolate Wi-Fi
- Endpoint changes upstream (schema, rate limits) could alter decode cost
- Emulator vs physical device differences (syscall & DNS latency) – prefer physical for final numbers
- Consistency: identical headers, timeouts, retry=OFF mandatory for cross-platform parity


