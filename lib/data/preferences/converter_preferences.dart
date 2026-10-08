import 'package:flutter/foundation.dart';
import '../app_enums.dart';

@immutable
class ConverterPreferences {
  const ConverterPreferences({
    this.currency,
    this.btcMode,
    this.mode,
    this.fiatModeRaw,
    this.fiatModeActiveSlot,
    this.satsModeRaw,
    this.satsModeActiveSlot,
  });
  final Currency? currency;
  final BtcDisplayMode? btcMode;
  final String? mode;
  final String? fiatModeRaw;
  final String? fiatModeActiveSlot;
  final String? satsModeRaw;
  final String? satsModeActiveSlot;
  ConverterPreferences copyWith({
    Currency? currency,
    BtcDisplayMode? btcMode,
    String? mode,
    String? fiatModeRaw,
    String? fiatModeActiveSlot,
    String? satsModeRaw,
    String? satsModeActiveSlot,
  }) => ConverterPreferences(
    currency: currency ?? this.currency,
    btcMode: btcMode ?? this.btcMode,
    mode: mode ?? this.mode,
    fiatModeRaw: fiatModeRaw ?? this.fiatModeRaw,
    fiatModeActiveSlot: fiatModeActiveSlot ?? this.fiatModeActiveSlot,
    satsModeRaw: satsModeRaw ?? this.satsModeRaw,
    satsModeActiveSlot: satsModeActiveSlot ?? this.satsModeActiveSlot,
  );
}
