import 'package:flutter/foundation.dart';
import '../app_enums.dart';
import '../stack.dart';

@immutable
class PortfolioState {
  PortfolioState({
    List<Stack> stacks = const [],
    this.showPortfolio = false,
    List<HomeWidget> homeWidgetOrder = const [HomeWidget.stacks],
    this.totalImageData,
    this.totalColorKey,
    this.totalProjectedPrice,
    this.totalProjectedPriceCurrency,
  }) : stacks = List.unmodifiable(stacks),
       homeWidgetOrder = List.unmodifiable(homeWidgetOrder);
  const PortfolioState.defaults()
    : stacks = const [],
      showPortfolio = false,
      homeWidgetOrder = const [HomeWidget.stacks],
      totalImageData = null,
      totalColorKey = null,
      totalProjectedPrice = null,
      totalProjectedPriceCurrency = null;
  const PortfolioState._({
    required this.stacks,
    required this.showPortfolio,
    required this.homeWidgetOrder,
    required this.totalImageData,
    required this.totalColorKey,
    required this.totalProjectedPrice,
    required this.totalProjectedPriceCurrency,
  });
  final List<Stack> stacks;
  final bool showPortfolio;
  final List<HomeWidget> homeWidgetOrder;
  final String? totalImageData;
  final String? totalColorKey;
  final double? totalProjectedPrice;
  final String? totalProjectedPriceCurrency;
  PortfolioState copyWith({
    List<Stack>? stacks,
    bool? showPortfolio,
    List<HomeWidget>? homeWidgetOrder,
    String? totalImageData,
    String? totalColorKey,
    double? totalProjectedPrice,
    String? totalProjectedPriceCurrency,
    bool clearTotalImage = false,
    bool clearTotalColor = false,
    bool clearTotalProjectedPrice = false,
  }) => PortfolioState._(
    stacks: stacks == null ? this.stacks : List.unmodifiable(stacks),
    showPortfolio: showPortfolio ?? this.showPortfolio,
    homeWidgetOrder: homeWidgetOrder == null
        ? this.homeWidgetOrder
        : List.unmodifiable(homeWidgetOrder),
    totalImageData: clearTotalImage
        ? null
        : (totalImageData ?? this.totalImageData),
    totalColorKey: clearTotalColor
        ? null
        : (totalColorKey ?? this.totalColorKey),
    totalProjectedPrice: clearTotalProjectedPrice
        ? null
        : (totalProjectedPrice ?? this.totalProjectedPrice),
    totalProjectedPriceCurrency: clearTotalProjectedPrice
        ? null
        : (totalProjectedPriceCurrency ?? this.totalProjectedPriceCurrency),
  );
}
