# Mono Widget

Widget na ekran główny Androida, który jednym tapnięciem przełącza systemowy dźwięk
między **STEREO** a **MONO**.

Pod spodem to ukryte ustawienie `Settings.Secure.master_mono` — to samo, które siedzi
w *Ustawienia → Dostępność → Dźwięk mono*.

## Instalacja

1. Pobierz APK z zakładki **Releases** (albo z artefaktów workflow `Build APK`).
2. Zainstaluj na telefonie (trzeba zezwolić na instalację z nieznanych źródeł).
3. Nadaj jednorazowo uprawnienie z komputera z `adb` (USB lub debugowanie bezprzewodowe):

   ```
   adb shell pm grant pl.mihu.monowidget android.permission.WRITE_SECURE_SETTINGS
   ```

   Komendę można skopiować z ekranu aplikacji.
4. Dodaj widget „Mono / Stereo" na ekran główny.

Bez kroku 3 widget nie rzuci błędem — po prostu otworzy ekran Dostępności, gdzie
przełącznik trzeba kliknąć ręcznie.

Weryfikacja z komputera: `adb shell settings get secure master_mono` (1 = mono, 0 = stereo).

## Budowanie

Projekt buduje się wyłącznie na GitHub Actions — **w repo nie ma `gradle-wrapper.jar`**,
Gradle dostarcza akcja `gradle/actions/setup-gradle`.

- `Build APK` — uruchamia się przy pushu na `main`, przy tagu `v*` (wtedy tworzy Release)
  i ręcznie z zakładki Actions.
- `Wygeneruj keystore (jednorazowo)` — generuje stały klucz podpisujący.

### Dlaczego stały keystore ma znaczenie

Domyślny debug-keystore powstaje losowo przy każdym buildzie, więc kolejny APK nie
zainstaluje się na poprzednim (konflikt podpisu) — trzeba by odinstalować aplikację,
a to **kasuje nadany grant ADB**. Ze stałym kluczem aktualizacje idą w miejscu
i uprawnienie nadaje się raz.

Konfiguracja (raz):

1. Actions → *Wygeneruj keystore (jednorazowo)* → Run workflow.
2. Pobierz artefakt `keystore-secrets`.
3. Settings → Secrets and variables → Actions → dodaj cztery sekrety o nazwach zgodnych
   z nazwami plików: `SIGNING_KEYSTORE_B64`, `SIGNING_STORE_PASSWORD`,
   `SIGNING_KEY_ALIAS`, `SIGNING_KEY_PASSWORD`.
4. Usuń pobrany artefakt z GitHuba (zawiera klucz prywatny) i przechowaj kopię keystore
   w bezpiecznym miejscu — bez niego nie zaktualizujesz zainstalowanej aplikacji.

## Struktura

| Plik | Rola |
| --- | --- |
| `MonoController.kt` | odczyt/zapis `master_mono`, wykrycie braku uprawnienia, deep-link do Ustawień |
| `MonoWidgetProvider.kt` | render widgetu (`RemoteViews`) i obsługa tapnięcia |
| `MainActivity.kt` | status, komenda ADB do skopiowania, ręczny przełącznik |
