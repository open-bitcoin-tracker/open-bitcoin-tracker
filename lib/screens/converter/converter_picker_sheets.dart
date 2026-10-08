import 'package:flutter/material.dart';
import '../../data/app_enums.dart';
import '../../data/fiat.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/theme.dart';

class ConverterCurrencySheet extends StatelessWidget {
  const ConverterCurrencySheet({super.key, required this.current});

  final Currency current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          for (final c in Currency.values)
            ListTile(
              leading: SizedBox(
                width: 24,
                child: c == current
                    ? Icon(Icons.check, color: scheme.primary)
                    : null,
              ),
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: c.code,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' — ${currencyLabel(l10n, c)}'),
                  ],
                ),
              ),
              onTap: () => Navigator.of(context).pop(c),
            ),
        ],
      ),
    );
  }
}

/// Bottom-sheet picker for the converter's local Bitcoin display unit.
class ConverterBtcUnitSheet extends StatelessWidget {
  const ConverterBtcUnitSheet({super.key, required this.current});

  final BtcDisplayMode current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    Widget row(BtcDisplayMode m, String label) => ListTile(
      leading: SizedBox(
        width: 24,
        child: m == current ? Icon(Icons.check, color: scheme.primary) : null,
      ),
      title: Text(label),
      onTap: () => Navigator.of(context).pop(m),
    );
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        children: [
          row(BtcDisplayMode.sats, 'Bitcoin (${l10n.bitcoinDisplayModeSats})'),
          row(BtcDisplayMode.btc, 'Bitcoin (${l10n.bitcoinDisplayModeBtc})'),
        ],
      ),
    );
  }
}
