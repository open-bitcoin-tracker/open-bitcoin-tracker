import 'package:flutter/foundation.dart';
import '../app_enums.dart';

@immutable
class CurrencyPreferences {
  CurrencyPreferences({
    this.currency = Currency.usd,
    List<Currency> selectedCurrencies = const [Currency.usd],
  }) : selectedCurrencies = List.unmodifiable(selectedCurrencies);
  const CurrencyPreferences.defaults()
    : currency = Currency.usd,
      selectedCurrencies = const [Currency.usd];
  const CurrencyPreferences._({
    required this.currency,
    required this.selectedCurrencies,
  });
  final Currency currency;
  final List<Currency> selectedCurrencies;
  CurrencyPreferences copyWith({
    Currency? currency,
    List<Currency>? selectedCurrencies,
  }) => CurrencyPreferences._(
    currency: currency ?? this.currency,
    selectedCurrencies: selectedCurrencies == null
        ? this.selectedCurrencies
        : List.unmodifiable(selectedCurrencies),
  );
}
