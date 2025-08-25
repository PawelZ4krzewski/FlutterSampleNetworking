# Metrics collection

This folder stores measurement outputs used for the comparison study.

## Output files

- `loc_flutter.txt`: LOC count from `scripts/loc_flutter.sh`
- `build_size_apk.txt`: Android APK size in bytes from `scripts/build_size_android.sh`
- `build_size_aab.txt`: Android AAB size in bytes from `scripts/build_size_android.sh`
- `build_size_ipa.txt`: iOS app bundle size in bytes from `scripts/build_size_ios.sh`
- `results_template.csv`: template for manual results logging
- `results_YYYYMMDD.csv`: actual measurement results

## Workflow

1. Copy `results_template.csv` to a new CSV (e.g., `results_20250825.csv`).
2. Record median and P95 from 20–50 request runs per scenario (T1–T4).
3. Fill timestamps in ms (epoch), duration, success/error status, and notes.
4. For clean measurements: keep `AppConfig.enableRetry=false`.
5. Optional: grep `NET_GET_MS` from logs to populate CSV (use `scripts/parse_net_logs_to_csv.sh` if available).

## Notes

- Network timing logs: exactly one `NET_GET_MS: <ms>` per request
- Interceptors: disabled in release builds to avoid overhead
- Both baseline and minified build sizes should be measured
