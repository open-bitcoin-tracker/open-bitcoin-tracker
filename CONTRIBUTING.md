# Contributing

## Setup and checks

Use **Flutter 3.41.7**, the version pinned in [CI](.github/workflows/check.yml), with Dart satisfying `^3.11.5` in [pubspec.yaml](pubspec.yaml). Install the Android SDK and JDK 17. Android SDK levels come from Flutter defaults in [android/app/build.gradle.kts](android/app/build.gradle.kts).

If Flutter has not generated `android/local.properties`, create it with your SDK paths:

```properties
sdk.dir=/path/to/android-sdk
flutter.sdk=/path/to/flutter
```

```bash
flutter pub get
flutter devices
flutter run -d <device-id>
```

Use the device ID reported by `flutter devices`. In the running terminal, press `r` for hot reload, `R` for hot restart, or `q` to quit.

Before submitting changes, run the same checks as CI:

```bash
bash tools/check.sh
```

The script installs dependencies, checks Dart formatting, runs static analysis, and runs tests. For a focused check, use `flutter analyze` or `flutter test test/path_to_test.dart`. Update images in `test/goldens/` only for intentional visual changes.

## Builds and installation

```bash
flutter build apk --debug
flutter build apk --release --target-platform android-arm,android-arm64
flutter build appbundle --release --target-platform android-arm,android-arm64
```

APKs land in `build/app/outputs/flutter-apk/`; the release bundle lands in `build/app/outputs/bundle/release/`. Release Gradle configuration targets ARM ABIs; pass the matching Flutter target flag above. For an arm64-only device, use `--target-platform android-arm64`.

For signed release builds, set `BTC_KEYSTORE_PROPERTIES` to an external properties file containing `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`. Keep signing files and secrets outside version control. Without a valid configuration, Gradle falls back to debug signing; do not distribute that build as an official release.

To upgrade a device with existing holdings, use:

```bash
adb -s <device-id> install -r <apk-path>
```

Check the installed and new APK signing certificates with `apksigner verify --print-certs` before upgrading. Avoid `flutter install` on devices with existing data: it can uninstall on a signature mismatch. If `adb install -r` fails, resolve the failure without uninstalling or clearing app data.

## Code layout

| Directory | Responsibility |
| --- | --- |
| `lib/app/` | App shell and provider ownership; `lib/main.dart` handles startup |
| `lib/api/` | Kraken WebSocket prices and REST chart history |
| `lib/data/` | Immutable models, preference groups, JSON codec, storage, and market-history cache/fallback |
| `lib/state/` | ChangeNotifier controllers for settings, portfolio, converter, live prices, charts, and lock state |
| `lib/services/` | Authentication, encryption, Android security, images, haptics, and orientation |
| `lib/screens/`, `lib/widgets/`, `lib/theme/` | Feature UI, shared components, and design tokens |
| `lib/l10n/` | ARB translations and generated localization sources |
| `test/` | Unit, widget, storage-compatibility, and visual regression tests |
| `assets/`, `tools/` | Bundled history, fonts, icons, checks, and asset tooling |

Package versions live in `pubspec.yaml` and `pubspec.lock`.

## Persistence and market data

With lock disabled, stacks are plaintext in SharedPreferences. With lock enabled, the repository stores an AES-256-GCM envelope; PIN-derived keys use Argon2id, and key material is protected by secure storage or a biometric-only Keystore slot. Settings and the locked stack count remain outside the encrypted envelope.

Preserve the flat JSON storage format in `AppStateCodec`. `AppStateRepository` must retain its cached encrypted envelope during locked settings writes and serialize writes in call order. Before clearing the envelope when disabling lock, drain pending saves. Device mode requires an enrolled biometric; a device PIN cannot release its encryption key.

Kraken provides live prices and recent OHLC history. Long-range charts merge `assets/btc_history.csv` with cached history on every refresh. Bundled dates replace cached values for those dates, cached days outside bundle coverage are retained, and fresh Kraken prices take precedence over both. The merged history is saved even when Kraken is unavailable. Both CSV loaders interpret dates as UTC; chart windows, axes, and conversions derive from the loaded points without fixed end dates or row counts.

Bundled `assets/fx_history.csv` supplies historical currency conversion. Each point uses the latest reference rate on or before its UTC date; weekends and holidays carry the preceding rate, and dates beyond FX coverage retain the final known rate. Update both assets together when extending offline history, and rebuild the app to ship them. Refresh the FX asset with `bash tools/fetch_fx_history.sh [START_DATE] [END_DATE]` (requires curl, GNU awk, and GNU date). Review dataset changes before committing. Fetching this asset is development tooling, not an app network request.

## Localization

`lib/l10n/app_en.arb` is the template. Add new user-facing strings there only, unless translations are explicitly requested. Remove deleted keys from every `app_*.arb`; rename keys consistently wherever they exist. Preserve placeholder names, ICU syntax, and metadata. Portuguese copy targets Brazil.

Regenerate with `flutter gen-l10n`. Generated Dart files in `lib/l10n/generated/` are ignored and must not be edited manually. Review translated wording, plural output, and narrow-screen layout as well as running checks.

## Pull requests

Use [GitHub Issues](https://github.com/Max-Hodler/open-bitcoin-tracker/issues) for bugs and proposals; discuss substantial changes before implementing them. Keep PRs focused, follow existing code patterns, and include relevant validation. Contributions use the [MIT License](LICENSE).
