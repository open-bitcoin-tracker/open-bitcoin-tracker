import 'app_enums.dart';
import 'stack.dart';
import 'app_state_codec.dart';
import 'preferences/portfolio_state.dart';
import 'preferences/currency_preferences.dart';
import 'preferences/appearance_preferences.dart';
import 'preferences/chart_preferences.dart';
import 'preferences/security_preferences.dart';
import 'preferences/converter_preferences.dart';

class AppState {
  const AppState({
    this.portfolio = const PortfolioState.defaults(),
    this.currencies = const CurrencyPreferences.defaults(),
    this.appearance = const AppearancePreferences(),
    this.chart = const ChartPreferences(),
    this.security = const SecurityPreferences(),
    this.converter = const ConverterPreferences(),
  });
  final PortfolioState portfolio;
  final CurrencyPreferences currencies;
  final AppearancePreferences appearance;
  final ChartPreferences chart;
  final SecurityPreferences security;
  final ConverterPreferences converter;
  List<Stack> get stacks => portfolio.stacks;
  Currency get currency => currencies.currency;
  List<Currency> get selectedCurrencies => currencies.selectedCurrencies;
  bool get showPortfolio => portfolio.showPortfolio;
  bool get showChart => chart.showChart;
  ChartHeight get chartHeight => chart.chartHeight;
  AppTheme get theme => appearance.theme;
  DarkVariant get darkVariant => appearance.darkVariant;
  LightVariant get lightVariant => appearance.lightVariant;
  BtcRange get btcRange => chart.btcRange;
  BtcRange get daysOverflowQuickRange => chart.daysOverflowQuickRange;
  BtcRange get weeksOverflowQuickRange => chart.weeksOverflowQuickRange;
  BtcRange get overflowQuickRange => chart.overflowQuickRange;
  BtcRange get monthsOverflowQuickRange => chart.monthsOverflowQuickRange;
  bool get logScale => chart.logScale;
  BtcDisplayMode get btcDisplayMode => appearance.btcDisplayMode;
  StacksAuthMode get stacksAuthMode => security.authMode;
  StacksLockTimeout get stacksLockTimeout => security.lockTimeout;
  LanguagePref get language => appearance.language;
  LivePriceCadence get livePriceCadence => chart.livePriceCadence;
  Currency? get converterCurrency => converter.currency;
  BtcDisplayMode? get converterBtcMode => converter.btcMode;
  String? get converterMode => converter.mode;
  String? get converterFiatModeRaw => converter.fiatModeRaw;
  String? get converterFiatModeActiveSlot => converter.fiatModeActiveSlot;
  String? get converterSatsModeRaw => converter.satsModeRaw;
  String? get converterSatsModeActiveSlot => converter.satsModeActiveSlot;
  List<HomeWidget> get homeWidgetOrder => portfolio.homeWidgetOrder;
  String? get totalImageData => portfolio.totalImageData;
  String? get totalColorKey => portfolio.totalColorKey;
  double? get totalProjectedPrice => portfolio.totalProjectedPrice;
  String? get totalProjectedPriceCurrency =>
      portfolio.totalProjectedPriceCurrency;
  bool get swipeChipHintDismissed => chart.swipeChipHintDismissed;
  bool get priceSwipeHintDismissed => chart.priceSwipeHintDismissed;
  bool get showPriceDelta => chart.showPriceDelta;
  AppState copyWith({
    List<Stack>? stacks,
    Currency? currency,
    List<Currency>? selectedCurrencies,
    bool? showPortfolio,
    bool? showChart,
    ChartHeight? chartHeight,
    AppTheme? theme,
    DarkVariant? darkVariant,
    LightVariant? lightVariant,
    BtcRange? btcRange,
    BtcRange? daysOverflowQuickRange,
    BtcRange? weeksOverflowQuickRange,
    BtcRange? overflowQuickRange,
    BtcRange? monthsOverflowQuickRange,
    bool? logScale,
    BtcDisplayMode? btcDisplayMode,
    StacksAuthMode? stacksAuthMode,
    StacksLockTimeout? stacksLockTimeout,
    LanguagePref? language,
    LivePriceCadence? livePriceCadence,
    Currency? converterCurrency,
    BtcDisplayMode? converterBtcMode,
    String? converterMode,
    String? converterFiatModeRaw,
    String? converterFiatModeActiveSlot,
    String? converterSatsModeRaw,
    String? converterSatsModeActiveSlot,
    List<HomeWidget>? homeWidgetOrder,
    String? totalImageData,
    bool clearTotalImage = false,
    String? totalColorKey,
    bool clearTotalColor = false,
    double? totalProjectedPrice,
    bool clearTotalProjectedPrice = false,
    String? totalProjectedPriceCurrency,
    bool? swipeChipHintDismissed,
    bool? priceSwipeHintDismissed,
    bool? showPriceDelta,
    PortfolioState? portfolio,
    CurrencyPreferences? currencies,
    AppearancePreferences? appearance,
    ChartPreferences? chart,
    SecurityPreferences? security,
    ConverterPreferences? converter,
  }) => AppState(
    portfolio:
        portfolio ??
        ((stacks != null ||
                showPortfolio != null ||
                homeWidgetOrder != null ||
                totalImageData != null ||
                totalColorKey != null ||
                totalProjectedPrice != null ||
                totalProjectedPriceCurrency != null ||
                clearTotalImage ||
                clearTotalColor ||
                clearTotalProjectedPrice)
            ? this.portfolio.copyWith(
                stacks: stacks,
                showPortfolio: showPortfolio,
                homeWidgetOrder: homeWidgetOrder,
                totalImageData: totalImageData,
                totalColorKey: totalColorKey,
                totalProjectedPrice: totalProjectedPrice,
                totalProjectedPriceCurrency: totalProjectedPriceCurrency,
                clearTotalImage: clearTotalImage,
                clearTotalColor: clearTotalColor,
                clearTotalProjectedPrice: clearTotalProjectedPrice,
              )
            : this.portfolio),
    currencies:
        currencies ??
        ((currency != null || selectedCurrencies != null)
            ? this.currencies.copyWith(
                currency: currency,
                selectedCurrencies: selectedCurrencies,
              )
            : this.currencies),
    appearance:
        appearance ??
        ((theme != null ||
                darkVariant != null ||
                lightVariant != null ||
                language != null ||
                btcDisplayMode != null)
            ? this.appearance.copyWith(
                theme: theme,
                darkVariant: darkVariant,
                lightVariant: lightVariant,
                language: language,
                btcDisplayMode: btcDisplayMode,
              )
            : this.appearance),
    chart:
        chart ??
        ((showChart != null ||
                chartHeight != null ||
                btcRange != null ||
                daysOverflowQuickRange != null ||
                weeksOverflowQuickRange != null ||
                overflowQuickRange != null ||
                monthsOverflowQuickRange != null ||
                logScale != null ||
                livePriceCadence != null ||
                swipeChipHintDismissed != null ||
                priceSwipeHintDismissed != null ||
                showPriceDelta != null)
            ? this.chart.copyWith(
                showChart: showChart,
                chartHeight: chartHeight,
                btcRange: btcRange,
                daysOverflowQuickRange: daysOverflowQuickRange,
                weeksOverflowQuickRange: weeksOverflowQuickRange,
                overflowQuickRange: overflowQuickRange,
                monthsOverflowQuickRange: monthsOverflowQuickRange,
                logScale: logScale,
                livePriceCadence: livePriceCadence,
                swipeChipHintDismissed: swipeChipHintDismissed,
                priceSwipeHintDismissed: priceSwipeHintDismissed,
                showPriceDelta: showPriceDelta,
              )
            : this.chart),
    security:
        security ??
        ((stacksAuthMode != null || stacksLockTimeout != null)
            ? this.security.copyWith(
                authMode: stacksAuthMode,
                lockTimeout: stacksLockTimeout,
              )
            : this.security),
    converter:
        converter ??
        ((converterCurrency != null ||
                converterBtcMode != null ||
                converterMode != null ||
                converterFiatModeRaw != null ||
                converterFiatModeActiveSlot != null ||
                converterSatsModeRaw != null ||
                converterSatsModeActiveSlot != null)
            ? this.converter.copyWith(
                currency: converterCurrency,
                btcMode: converterBtcMode,
                mode: converterMode,
                fiatModeRaw: converterFiatModeRaw,
                fiatModeActiveSlot: converterFiatModeActiveSlot,
                satsModeRaw: converterSatsModeRaw,
                satsModeActiveSlot: converterSatsModeActiveSlot,
              )
            : this.converter),
  );

  Map<String, dynamic> toJson({bool includeStacks = true}) =>
      AppStateCodec.encode(this, includeStacks: includeStacks);
  factory AppState.fromJson(Map<String, dynamic> json) =>
      AppStateCodec.decode(json);
}
