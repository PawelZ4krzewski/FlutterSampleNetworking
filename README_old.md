# Flutter networking sample (Compose parity)

Parametry do uzupełnienia przed uruchomieniem:

- Endpoint API: WSTAW_URL (np. https://jsonplaceholder.typicode.com/posts)
- Platformy uruchomieniowe dziś: Android+iOS
- IDE/środowisko: Android Studio lub VS Code
- System operacyjny: macOS

## Plan kroków (~2h)

[10 min] Inicjalizacja projektu i pubspec
- Cel: gotowy projekt z zależnością `dio`.
- Komendy:
  - flutter create flutter_sample_networking
  - wpisz dependency w pubspec.yaml i uruchom `flutter pub get`
- Kod: zobacz `pubspec.yaml` w repo (z `dio: ^5`).
- Walidacja: `flutter pub get` bez błędów.

[15 min] Struktura katalogów i AppConfig
- Cel: parytet warstw i miejsca na konfigurację.
- Rezultat: `lib/core/app_config.dart`, timeouty, retry flag.
- Walidacja: kompilacja, brak błędów importów.

[15 min] Model Post + klient Dio
- Cel: `Post`, `ApiClient` z timeouts, interceptor, pomiar czasu.
- Walidacja: uruchom aplikację z prawidłowym URL; w logu widać request/response i czasy w ms.

[15 min] Repozytorium, mapowanie błędów, retry flagą
- Cel: prosty `Result<T>` i mapowanie `DioException` -> `AppError`.
- Walidacja: symulacja błędów (offline/timeout/500) pokazuje odpowiedni komunikat i log.

[20 min] Ekran DataScreen + ErrorView + logowanie czasu
- Cel: ekran z Loading/List/Error i przyciskiem Retry.
- Walidacja: lista pokazuje 2–3 pola (title, body), retry działa.

[15 min] Testy jednostkowe
- Cel: test mapowania błędów i dekodowania modelu.
- Walidacja: `flutter test` zielony.

[10 min] Skrypty LOC i build-size
- Cel: policzyć LOC i rozmiary buildów.
- Walidacja: pliki w `metrics/*.txt` zawierają wartości (bajty lub output cloc).

[10 min] README + instrukcje profilerów
- Cel: samoopis projektu i kroki pomiarowe.

[10 min] Walidacja T1–T4 i zapis wyników
- Cel: przejść checklistę funkcjonalną i zarejestrować pomiary.

## Struktura i warstwy

- data/
  - client+model: `data/api_client.dart`, `data/models/post.dart`
- domain/
  - repository: `domain/repository.dart` (Result<T>)
- ui/
  - screen: `ui/screens/DataScreen`
  - widgets: `ui/widgets/ErrorView`
- core/
  - config, błędy, timing

## Uzasadnienie wyboru Dio

- Lepsza kontrola timeoutów (connect/send/receive) niż goły `http`.
- Interceptory (logowanie, header’y, metryki) bez dodatkowych pakietów.
- Spójne mapowanie błędów (DioExceptionType) i prosty retry.

## Instrukcje uruchomienia

Tryby uruchomienia:

Profil (pomiar) – deterministyczny config via --dart-define:

```bash
flutter run --profile \
  --dart-define=BASE_URL=https://jsonplaceholder.typicode.com/posts \
  --dart-define=CONNECT_TIMEOUT_MS=8000 \
  --dart-define=SEND_TIMEOUT_MS=8000 \
  --dart-define=RECEIVE_TIMEOUT_MS=8000
```

Uwaga: enableRetry=false domyślnie w `AppConfig` dla rzetelnych pomiarów.

Dev/Debug (szybkie sprawdzanie):

```bash
flutter run --dart-define=BASE_URL=https://jsonplaceholder.typicode.com/posts
```

W IDE:
- Android Studio/VS Code: otwórz projekt, wybierz emulator/urządzenie, Run ▶.

## Wyświetlanie

- Lista kart (`Card`) z `title` i `body`.

## Obsługa błędów i retry

- UI: `ErrorView` z komunikatem i przyciskiem Retry.
- Log: `print` + `AppConfig.log`, mapowanie: offline/timeout/4xx/5xx/cancel/unknown.
- Retry/backoff: kontrolowany flagą `AppConfig.enableRetry` (1 dodatkowa próba po 500 ms).

## Pomiary czasu i timeouty

- Pomiar czasu wyłącznie w warstwie data (`ApiClient.fetchPosts()`).
- Jeden log na żądanie: `NET_GET_MS: <ms>` (patrz `AppConfig.timingLabelNetGet`).
- Timeouts ustawiane przez `--dart-define` (domyślnie 8000ms). Zobacz `AppConfig`.

## Build release i rozmiary

- Android APK/AAB: `bash scripts/build_size_android.sh`.
- iOS (no-codesign): `bash scripts/build_size_ios.sh` (macOS, Xcode).
- Rozmiary zapisane do: `metrics/build_size_apk.txt`, `metrics/build_size_aab.txt`, `metrics/build_size_ipa.txt`.

## Profilery

- Android Studio: Run > Profiler, nagraj CPU/Memory; zapisz trace z panelu Profiler.
- iOS Instruments: Profile (Cmd+I w Xcode po zbudowaniu) > wybrany instrument > nagrywanie i zapis trace.
- Interceptory Dio są wyłączone w release, dołączone tylko w debug/profile.

## Testy funkcjonalne (T1–T4)

- T1: Sukces GET → lista widoczna.
- T2: Offline (tryb samolotowy) → komunikat + brak crasha.
- T3: Timeout (uruchom z `--dart-define=CONNECT_TIMEOUT_MS=1000`) → odpowiedni komunikat.
- T4: 500/404 (zmień URL na endpoint błędu) → odpowiedni komunikat.

Jak wymusić warunki:
- Offline: tryb samolotowy lub odłącz sieć.
- Timeout: ustaw 1000ms dla CONNECT/SEND/RECEIVE w dart-define.
- 5xx/404: wskaż bazowy URL do endpointu zwracającego błąd.

## Kontrola parytetu

- Nazewnictwo warstw: data/client+model, domain/repository, ui/screen – jak w Compose.
- Różnice nieusuwalne: widgety Material vs. Compose UI idiomy; brak wpływu na warstwę data/domain.
- Timeouts/retry/logging ustawione symetrycznie; różnice w API logowania wynikają z frameworka.

## Pomiary i skrypty

- LOC: `bash scripts/loc_flutter.sh` → `metrics/loc_flutter.txt`
- Rozmiar buildów Android: `bash scripts/build_size_android.sh` → `metrics/build_size_apk.txt`, `metrics/build_size_aab.txt`
- Rozmiar iOS: `bash scripts/build_size_ios.sh` → `metrics/build_size_ipa.txt`

## Auto-check: warunki a–d

- (a) Pobiera te same dane (endpoint z parametru): TAK – `AppConfig.baseUrl`.
- (b) Wyświetla je podobnie (lista/karty z tymi samymi polami): TAK – title/body.
- (c) Loguje czasy i błędy: TAK – jeden log `NET_GET_MS: <ms>` per request + mapowanie błędów.
- (d) Gotowe komendy do policzenia LOC i rozmiarów buildów: TAK – skrypty w `scripts/` + wyniki w `metrics/`.


