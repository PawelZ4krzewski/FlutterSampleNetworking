# Flutter Networking Sample

A research-focused Flutter application demonstrating HTTP networking patterns using Dio, designed for performance comparison studies.

## Architecture

Clean architecture with three layers:
- **data/**: HTTP client (`ApiClient`), models (`Post`), repositories
- **domain/**: Repository interfaces and business logic
- **ui/**: Screens and widgets using Material 3

## Networking

Uses Dio 5.x for HTTP operations with:
- Connection and receive timeouts
- Request timing measurements
- Retry logic with exponential backoff
- Error mapping to typed `AppError` enum
- Release-safe interceptors (disabled in production)

## Measurement hygiene

For consistent performance measurements:

1. **Configuration**: Use `--dart-define` flags for deterministic setup:
   ```bash
   flutter run --dart-define=BASE_URL=https://api.example.com
   ```

2. **Warm-up**: Always perform 2-3 warm-up requests before measurement

3. **Sample size**: Use N=20-50 requests per test scenario

4. **Metrics**: Report median and P95 response times

5. **Retry policy**: Keep `AppConfig.enableRetry=false` during timing tests

6. **Timing logs**: Look for `NET_GET_MS: <milliseconds>` in console output

## Build variants

Measure both configurations:
- **Baseline**: `flutter build apk` or `flutter build ios`
- **Minified**: `flutter build apk --obfuscate --split-debug-info=symbols/` or equivalent

## Configuration

Required `--dart-define` parameters:
- `BASE_URL`: API endpoint (enforced - no default fallback)

Optional parameters:
- `CONNECTION_TIMEOUT_MS`: default 10000
- `RECEIVE_TIMEOUT_MS`: default 15000
- `ENABLE_RETRY`: default false

Example:
```bash
flutter run --dart-define=BASE_URL=https://jsonplaceholder.typicode.com
```

## Development

```bash
# Install dependencies
flutter pub get

# Run tests
flutter test

# Analyze code
flutter analyze

# Build for measurement
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
```

## Measurement scripts

Use included scripts for consistent measurements:

```bash
# Count lines of code
./scripts/loc_flutter.sh

# Measure Android build sizes
./scripts/build_size_android.sh

# Measure iOS build size (macOS only)
./scripts/build_size_ios.sh
```

Results are saved to `metrics/` folder. See `metrics/README.md` for CSV workflow.

## Test scenarios

Implement these test cases:
- **T1**: Single GET request (timing measurement)
- **T2**: Multiple parallel requests (concurrency test)
- **T3**: Error handling (network timeout, HTTP 4xx/5xx)
- **T4**: Large payload parsing (JSON decode performance)

All scenarios use the `/posts` endpoint returning `Post[]` models.

## Dependencies

- Flutter 3.3+
- Dio 5.4+ (HTTP client)
- Material 3 (UI framework)

No code generation or complex state management to maintain comparability with Compose Multiplatform baseline.
