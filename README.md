## Opis

Projekt prezentuje spójny przykład warstwy sieciowej w aplikacji mobilnej zorientowany na badanie wydajności (porównanie z implementacją w innym ekosystemie). Zawiera mechanizmy pomiaru opóźnień, kontrolowane środowisko uruchomieniowe oraz ekran benchmarków umożliwiający replikowalne eksperymenty.

## Cele

- Uzyskanie deterministycznych (powtarzalnych) pomiarów czasów odpowiedzi.
- Zachowanie prostoty modeli i brak generowania kodu, aby zminimalizować czynniki zakłócające.
- Wyraźne rozdzielenie odpowiedzialności (konfiguracja, klient HTTP, logika domenowa, UI).
- Udostępnienie gotowych scenariuszy S1–S6 (payload, lista, błąd 500, timeout, offline, echo nagłówków).

## Architektura

Struktura modułowa inspirowana prostą „clean architecture”:
- `core/` – konfiguracja (wartości z `--dart-define`), typy błędów, narzędzia pomiarowe.
- `data/` – klient HTTP (Dio), modele danych, dekodowanie JSON, operacje sieciowe.
- `domain/` – repozytorium udostępniające spójny interfejs dla UI.
- `bench/` – logika benchmarków (uruchamianie serii, agregacja statystyk, eksport wyników).
- `ui/` – ekrany (lista danych + ekran Benchmark), komponenty prezentacyjne.

## Stos technologiczny

- Framework UI i wieloplatformowość.
- Biblioteka HTTP (Dio) z konfigurowalnymi timeoutami i możliwością dopinania interceptorów.
- Ręczne mapowanie JSON → obiekty (brak codegen, pełna kontrola nad dekodowaniem).
- Standardowe narzędzia testowe do testów jednostkowych.

## Warstwa sieciowa

Klient tworzony z użyciem `BaseOptions` (nagłówki, timeouty). Każde wywołanie mierzone pojedynczym `Stopwatch`; wynik logowany jako `NET_GET_MS: <ms>`. Błędy mapowane do zunifikowanych typów (offline, timeout, 4xx, 5xx, cancel, unknown). W trybie pomiarowym retry jest wyłączony, aby nie zniekształcać metryk. Dekodowanie JSON: ręczne dopasowanie listy lub obiektu; odporność na drobne różnice typów (np. `id` jako String/Int).

## Scenariusze benchmarków (S1–S6)

| ID | Zakres | Opis | Endpoint bazowy | Ścieżka | Charakterystyka |
|----|--------|------|-----------------|---------|-----------------|
| S1 | Small | Pojedynczy mały obiekt | dummyjson.com | /posts/1 | Minimalny narzut dekodowania |
| S2 | List | Lista ok. 100 elementów | dummyjson.com | /posts?limit=100 | Test kosztu dekodowania listy |
| S3 | Error | Deterministyczny błąd serwera | httpbingo.org | /status/500 | Stałe 500, ścieżka błędu |
| S4 | Timeout | Sztuczne opóźnienie (klient 1s) | httpbingo.org | /delay/10 | Wymuszone przekroczenie limitu |
| S5 | Offline | Tryb samolotowy | dummyjson.com | /posts/1 | Błąd połączenia / szybki fail |
| S6 | Headers | Echo nagłówków | httpbingo.org | /headers | Weryfikacja nagłówków żądania |

Interpretacja: W scenariuszach błędowych (S3–S5) mierzymy koszt obsługi ścieżki błędu; w pozostałych – czas pobrania + dekodowania.

## Metodyka pomiarów

- N (liczba prób): standardowo 30 (pierwsza odrzucona jako warm-up → 29 analizowanych).
- Miary wyjściowe: median (robust), p95 (ogon opóźnień), min, max.
- P95: indeks obliczany jako floor(0.95*(n-1)) na posortowanej liście czasów.
- Logowanie: dokładnie jeden wpis `NET_GET_MS` na zapytanie (warstwa danych).
- Środowisko: tryb profilowy lub zbliżony (na symulatorze dopuszczalny debug – z adnotacją).
- Brak równoległości – sekwencyjne żądania eliminują interferencje.
- Retry wyłączony (czystość statystyk). Możliwość włączenia jedynie w analizie funkcjonalnej.

## Uruchomienie

Instalacja zależności:
```
flutter pub get
```

Analiza i testy:
```
flutter analyze
flutter test
```

Uruchomienie z parametrami (przykład):
```
flutter run --profile \
  --dart-define=BASE_URL=https://dummyjson.com \
  --dart-define=CONNECT_TIMEOUT_MS=8000 \
  --dart-define=SEND_TIMEOUT_MS=8000 \
  --dart-define=RECEIVE_TIMEOUT_MS=8000
```

Ekran benchmarków: wybierz preset S1–S6, ustaw N=30, włącz warm-up, uruchom. Po zakończeniu użyj eksportu (CSV / Markdown) lub logu zbiorczego.

## Struktura katalogów (skrót)

```
lib/
  core/        # konfiguracja + typy błędów + narzędzia
  data/        # klient HTTP, modele, implementacja repo
  domain/      # interfejs repozytorium
  bench/       # runner, presety, agregacja, eksport
  ui/          # ekrany i widżety prezentacyjne
test/unit/     # testy jednostkowe (dekodowanie, błędy, runner)
scripts/       # pomiary rozmiaru, LOC, parsowanie logów
```

## Testy

Warstwa testowa obejmuje:
- Dekodowanie modeli (sprawdzenie odporności na różne typy pól).
- Mapowanie błędów (typy timeout / offline / 4xx / 5xx / cancel / unknown).
- Agregację benchmarków (median, p95, odrzucenie warm-up, zliczanie błędów).
