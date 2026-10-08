import 'package:flutter/foundation.dart';

/// Which two units the converter is currently bridging.
/// - [fiat]: fiat ↔ Bitcoin (uses live BTC rate)
/// - [sats]: BTC ↔ sats (pure unit conversion, no rate)
enum ConverterMode { fiat, sats }

/// The two cards on the converter screen, by visual position. The previous
/// `ConverterSide.fiat`/`sats` naming had different meanings in each mode
/// (the "fiat" slot held sats in sats mode); `top`/`bottom` is mode-neutral.
enum ConverterSlot { top, bottom }

/// Per-mode state: what the user is typing, where the caret sits, and which
/// slot they're typing into. The non-active slot is always derived at render
/// time; it never lives in state.
@immutable
class ConverterEntry {
  const ConverterEntry({
    this.raw = '',
    this.caret = 0,
    this.active = ConverterSlot.top,
  });

  /// The raw string the user has typed, in the active slot's display unit.
  /// Locale-neutral: '.' decimal separator, no grouping. Empty == no input.
  final String raw;
  // Caret position in [raw], in [0, raw.length].
  final int caret;
  // Which slot the user is editing.
  final ConverterSlot active;

  ConverterEntry copyWith({String? raw, int? caret, ConverterSlot? active}) =>
      ConverterEntry(
        raw: raw ?? this.raw,
        caret: caret ?? this.caret,
        active: active ?? this.active,
      );
}
