# Open Bitcoin Tracker

Open Bitcoin Tracker (OBT) is a free, open-source Android app for tracking the value of your bitcoin. Enter holdings manually; the app does not hold funds, manage keys, or send transactions.

## Install

Download an APK from [GitHub Releases](https://github.com/Max-Hodler/open-bitcoin-tracker/releases). Enable **Install unknown apps** for your browser or file manager if Android prompts you. To preserve existing app data, upgrade with an APK signed by the same distributor; uninstalling deletes local holdings.

## Features

- Live BTC prices from Kraken, with configurable display update frequency and a full-screen price view.
- Named stacks with custom colors or images, reordering, and a combined portfolio total.
- Historical price and stack-value charts, bundled data for offline viewing, and future-value projections.
- Conversion between BTC, satoshis, and USD, EUR, GBP, AUD, CAD, CHF, or JPY.
- BTC or satoshi display, PIN or biometric stack lock, and a configurable background lock timeout.
- System, light, and dark appearance, with two light and two dark palettes.
- German, English, Spanish, French, Italian, Japanese, Portuguese, Russian, Turkish, and Vietnamese.

## Privacy and security

Holdings, settings, and stack images stay on your device. There are no accounts, cloud sync, analytics, or telemetry, and no public keys are required. Network requests fetch live prices and chart history from Kraken; bundled Bitcoin and exchange-rate history support offline charts. Links in the About screen open in your browser.

Enabling stack lock encrypts holdings with AES-256-GCM. PIN protection uses Argon2id; biometric access uses Android Keystore. Holdings are stored unencrypted when lock is disabled. Android backup is disabled, and enabling lock also blocks screenshots and screen capture.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, checks, and builds. Report bugs and suggest features in [GitHub Issues](https://github.com/Max-Hodler/open-bitcoin-tracker/issues).

## License

[MIT](LICENSE).
