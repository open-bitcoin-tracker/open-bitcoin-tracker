import 'app_state.dart';
import 'app_enums.dart';
import 'stack.dart';

/// Keeps the existing flat JSON storage contract independent of state grouping.
abstract final class AppStateCodec {
  static Map<String, dynamic> encode(
    AppState state, {
    bool includeStacks = true,
  }) => {
    if (includeStacks) 'stacks': state.stacks.map((s) => s.toJson()).toList(),
    'currency': state.currency.code,
    'selectedCurrencies': [for (final c in state.selectedCurrencies) c.code],
    'showPortfolio': state.showPortfolio,
    'showChart': state.showChart,
    'chartHeight': state.chartHeight.code,
    'theme': state.theme.code,
    'darkVariant': state.darkVariant.code,
    'lightVariant': state.lightVariant.code,
    'btcRange': state.btcRange.code,
    'daysOverflowQuickRange': state.daysOverflowQuickRange.code,
    'weeksOverflowQuickRange': state.weeksOverflowQuickRange.code,
    'overflowQuickRange': state.overflowQuickRange.code,
    'monthsOverflowQuickRange': state.monthsOverflowQuickRange.code,
    'logScale': state.logScale,
    'bitcoinDisplayMode': state.btcDisplayMode.code,
    'stacksAuthMode': state.stacksAuthMode.code,
    'stacksLockTimeout': state.stacksLockTimeout.code,
    'language': state.language.code,
    'livePriceCadence': state.livePriceCadence.code,
    if (state.converterCurrency != null)
      'converterCurrency': state.converterCurrency!.code,
    if (state.converterBtcMode != null)
      'converterBtcMode': state.converterBtcMode!.code,
    if (state.converterMode != null) 'converterMode': state.converterMode,
    if (state.converterFiatModeRaw != null)
      'converterFiatModeRaw': state.converterFiatModeRaw,
    if (state.converterFiatModeActiveSlot != null)
      'converterFiatModeActiveSlot': state.converterFiatModeActiveSlot,
    if (state.converterSatsModeRaw != null)
      'converterSatsModeRaw': state.converterSatsModeRaw,
    if (state.converterSatsModeActiveSlot != null)
      'converterSatsModeActiveSlot': state.converterSatsModeActiveSlot,
    'homeWidgetOrder': [for (final w in state.homeWidgetOrder) w.code],
    if (state.totalImageData != null) 'totalImageData': state.totalImageData,
    if (state.totalColorKey != null) 'totalColorKey': state.totalColorKey,
    if (state.totalProjectedPrice != null)
      'totalProjectedPrice': state.totalProjectedPrice,
    if (state.totalProjectedPriceCurrency != null)
      'totalProjectedPriceCurrency': state.totalProjectedPriceCurrency,
    'swipeChipHintDismissed': state.swipeChipHintDismissed,
    'priceSwipeHintDismissed': state.priceSwipeHintDismissed,
    'showPriceDelta': state.showPriceDelta,
  };

  static AppState decode(Map<String, dynamic> json) {
    final rawStacks = json['stacks'];
    final stacks = rawStacks is List
        ? rawStacks.map(Stack.fromJson).whereType<Stack>().toList()
        : const <Stack>[];

    // Reads json[key] as a nullable String and forwards it to fromCode. Every
    // enum's fromCode returns its own documented default when the input is
    // null or unknown, so missing/garbage keys don't need handling here.
    T fromCode<T>(String key, T Function(String?) parse) =>
        parse(json[key] as String?);

    final currency = fromCode('currency', Currency.fromCode);
    final selectedCurrencies = _parseSelectedCurrencies(
      json['selectedCurrencies'],
      currency,
    );

    return const AppState().copyWith(
      stacks: stacks,
      currency: currency,
      selectedCurrencies: selectedCurrencies,
      showPortfolio: json['showPortfolio'] as bool? ?? false,
      showChart: json['showChart'] as bool? ?? true,
      chartHeight: ChartHeight.fromCode(json['chartHeight'] as String?),
      theme: fromCode('theme', AppTheme.fromCode),
      darkVariant: fromCode('darkVariant', DarkVariant.fromCode),
      lightVariant: fromCode('lightVariant', LightVariant.fromCode),
      // btcRange is special-cased like the overflow chips: a missing key means
      // first launch, so land on the intended default (all) rather than
      // BtcRange.fromCode's general fallback (y10).
      btcRange: json['btcRange'] is String
          ? BtcRange.fromCode(json['btcRange'] as String)
          : BtcRange.all,
      // The overflow chips are special-cased: a missing key (vs. a wrong code)
      // means "the user has never opened the picker", so land on the default
      // slot rather than BtcRange.fromCode's general default.
      daysOverflowQuickRange: json['daysOverflowQuickRange'] is String
          ? BtcRange.fromCode(json['daysOverflowQuickRange'] as String)
          : BtcRange.d1,
      weeksOverflowQuickRange: json['weeksOverflowQuickRange'] is String
          ? BtcRange.fromCode(json['weeksOverflowQuickRange'] as String)
          : BtcRange.w1,
      overflowQuickRange: json['overflowQuickRange'] is String
          ? BtcRange.fromCode(json['overflowQuickRange'] as String)
          : BtcRange.y10,
      monthsOverflowQuickRange: json['monthsOverflowQuickRange'] is String
          ? BtcRange.fromCode(json['monthsOverflowQuickRange'] as String)
          : BtcRange.m6,
      logScale: json['logScale'] as bool? ?? true,
      btcDisplayMode: fromCode('bitcoinDisplayMode', BtcDisplayMode.fromCode),
      stacksAuthMode: fromCode('stacksAuthMode', StacksAuthMode.fromCode),
      stacksLockTimeout: fromCode(
        'stacksLockTimeout',
        StacksLockTimeout.fromCode,
      ),
      language: fromCode('language', LanguagePref.fromCode),
      livePriceCadence: fromCode('livePriceCadence', LivePriceCadence.fromCode),
      // Nullable: legacy installs and fresh ones both produce null; the
      // converter screen seeds from [currency] on its first opened visit.
      // Unknown codes also fall to null rather than silently snapping to USD.
      converterCurrency: switch (json['converterCurrency']) {
        final String code =>
          Currency.values
              .where((c) => c.code == code)
              .cast<Currency?>()
              .firstWhere((_) => true, orElse: () => null),
        _ => null,
      },
      // Same null-friendly read as [converterCurrency]: unknown / missing
      // codes leave the field null so the converter seeds from the global
      // setting on its next visit.
      converterBtcMode: switch (json['converterBtcMode']) {
        final String code =>
          BtcDisplayMode.values
              .where((m) => m.code == code)
              .cast<BtcDisplayMode?>()
              .firstWhere((_) => true, orElse: () => null),
        _ => null,
      },
      converterMode: json['converterMode'] as String?,
      converterFiatModeRaw: json['converterFiatModeRaw'] as String?,
      converterFiatModeActiveSlot:
          json['converterFiatModeActiveSlot'] as String?,
      converterSatsModeRaw: json['converterSatsModeRaw'] as String?,
      converterSatsModeActiveSlot:
          json['converterSatsModeActiveSlot'] as String?,
      homeWidgetOrder: _parseHomeWidgetOrder(json['homeWidgetOrder']),
      totalImageData: json['totalImageData'] is String
          ? json['totalImageData'] as String
          : null,
      totalColorKey: json['totalColorKey'] is String
          ? json['totalColorKey'] as String
          : null,
      totalProjectedPrice: json['totalProjectedPrice'] is num
          ? (json['totalProjectedPrice'] as num).toDouble()
          : null,
      totalProjectedPriceCurrency:
          json['totalProjectedPriceCurrency'] as String?,
      swipeChipHintDismissed: json['swipeChipHintDismissed'] as bool? ?? false,
      priceSwipeHintDismissed:
          json['priceSwipeHintDismissed'] as bool? ?? false,
      showPriceDelta: json['showPriceDelta'] as bool? ?? false,
    );
  }

  // Pre-existing installs won't have `selectedCurrencies` in their JSON; fall
  // back to a single-element list of the active currency so the swipe gesture
  // opens the picker (the documented 1-element behavior) until they pick more.
  static List<Currency> _parseSelectedCurrencies(
    Object? raw,
    Currency fallbackCurrent,
  ) {
    if (raw is! List) return [fallbackCurrent];
    final out = <Currency>[];
    for (final item in raw) {
      if (item is! String) continue;
      // Skip unknown codes rather than silently coercing to the fallback —
      // `Currency.fromCode` would otherwise turn every garbage entry into a
      // duplicate of `fallbackCurrent`.
      final match = Currency.values
          .where((c) => c.code == item)
          .cast<Currency?>()
          .firstWhere((_) => true, orElse: () => null);
      if (match == null) continue;
      if (!out.contains(match)) out.add(match);
    }
    if (out.isEmpty) return [fallbackCurrent];
    if (!out.contains(fallbackCurrent)) {
      // The persisted current currency must be in the cycle list so the swipe
      // gesture can find it.
      out.insert(0, fallbackCurrent);
    }
    return out;
  }

  // Parses [HomeWidget] codes from JSON, preserving the user's order while
  // filling in any enum values missing from the persisted list. Removed enum
  // values get silently dropped (fromCode returns null for unknown codes).
  // Newly-added values are appended at the end.
  static List<HomeWidget> _parseHomeWidgetOrder(Object? raw) {
    const fallback = [HomeWidget.stacks];
    if (raw is! List) return fallback;
    final out = <HomeWidget>[];
    for (final item in raw) {
      if (item is! String) continue;
      final match = HomeWidget.fromCode(item);
      if (match == null) continue;
      if (!out.contains(match)) out.add(match);
    }
    for (final w in HomeWidget.values) {
      if (out.contains(w)) continue;
      out.add(w);
    }
    return out;
  }
}
