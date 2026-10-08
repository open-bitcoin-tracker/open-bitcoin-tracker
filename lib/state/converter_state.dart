import 'package:flutter/foundation.dart';

import '../data/app_enums.dart';
import '../data/sats.dart';
import '../data/converter_entry.dart';
import 'app_state_notifier.dart';
import 'converter_logic.dart' show entryFrom, parseMode;
export '../data/converter_entry.dart';

/// Single source of truth for the converter screen.
///
/// Two independent [ConverterEntry] snapshots, one per [ConverterMode], swap
/// in and out as the user toggles modes — so in-progress input in one mode
/// survives a trip through the other.
///
/// The fiat-mode bottom slot's raw is stored in whichever Bitcoin display
/// unit (sats integer vs BTC decimal) the converter was set to at the time
/// the user typed it. Display-unit changes go through [migrateFiatBtcDisplay]
/// from the picker handler — a synchronous, one-shot conversion — so the
/// unit interpretation of [raw] is always coherent with the *current* state,
/// without any post-frame re-sync machinery or "last-seen mode" bookkeeping.
class ConverterState extends ChangeNotifier {
  ConverterState({AppStateNotifier? app}) : _app = app {
    if (app == null) return;
    hydrateOnce(
      fiat: entryFrom(
        app.converterFiatModeRaw,
        app.converterFiatModeActiveSlot,
      ),
      sats: entryFrom(
        app.converterSatsModeRaw,
        app.converterSatsModeActiveSlot,
      ),
      mode: parseMode(app.converterMode) ?? ConverterMode.fiat,
    );
    onPersist = (mode, entry) {
      final write = mode == ConverterMode.fiat
          ? app.setConverterFiatModeEntry
          : app.setConverterSatsModeEntry;
      write(raw: entry.raw, activeSlot: entry.active.name);
    };
    onPersistMode = (mode) => app.setConverterMode(mode.name);
  }

  final AppStateNotifier? _app;

  /// Called on first screen entry, preserving the lazy first-visit defaults.
  void seedPreferences() {
    final app = _app;
    if (app == null) return;
    if (app.converterCurrency == null) app.setConverterCurrency(app.currency);
    if (app.converterBtcMode == null) {
      app.setConverterBtcMode(app.btcDisplayMode);
    }
  }

  ConverterMode mode = ConverterMode.fiat;
  ConverterEntry _fiat = const ConverterEntry();
  ConverterEntry _sats = const ConverterEntry();
  bool showLeadingZeroWarning = false;
  // Persistence hooks owned by this controller and injected at construction. [onPersist] fires
  // on every entry mutation (per-mode keystrokes, slot flips); [onPersistMode]
  // fires whenever the user toggles the converter mode. The controller routes
  // both into AppStateNotifier so values + mode survive app restarts.
  void Function(ConverterMode mode, ConverterEntry entry)? onPersist;
  void Function(ConverterMode mode)? onPersistMode;

  ConverterEntry get _live => mode == ConverterMode.fiat ? _fiat : _sats;

  String get raw => _live.raw;
  int get caret => _live.caret;
  ConverterSlot get active => _live.active;

  bool _hydrated = false;

  /// Hydrates once at construction; later calls leave in-progress input intact. Bypasses [onPersist]/[onPersistMode] — the
  /// caller is the source of truth.
  void hydrateOnce({
    required ConverterEntry fiat,
    required ConverterEntry sats,
    required ConverterMode mode,
  }) {
    if (_hydrated) return;
    _hydrated = true;
    _fiat = fiat;
    _sats = sats;
    this.mode = mode;
  }

  void _write(ConverterEntry next) {
    if (mode == ConverterMode.fiat) {
      _fiat = next;
    } else {
      _sats = next;
    }
    onPersist?.call(mode, next);
  }

  /// Replaces fields on the live entry. Notifies only if something changed.
  void edit({String? raw, int? caret, ConverterSlot? active, bool? warning}) {
    final cur = _live;
    final nextRaw = raw ?? cur.raw;
    final nextActive = active ?? cur.active;
    final nextCaret = raw != null
        ? (caret ?? nextRaw.length)
        : (caret != null ? caret.clamp(0, nextRaw.length) : cur.caret);
    final entryChanged =
        nextRaw != cur.raw ||
        nextActive != cur.active ||
        nextCaret != cur.caret;
    final warningChanged = warning != null && warning != showLeadingZeroWarning;
    if (entryChanged) {
      _write(
        ConverterEntry(raw: nextRaw, caret: nextCaret, active: nextActive),
      );
    }
    if (warningChanged) showLeadingZeroWarning = warning;
    if (entryChanged || warningChanged) notifyListeners();
  }

  /// Toggles the converter mode. Preserves the other mode's snapshot so the
  /// user can flip back and find their work intact.
  void setMode(ConverterMode next) {
    if (mode == next) return;
    mode = next;
    showLeadingZeroWarning = false;
    onPersistMode?.call(next);
    notifyListeners();
  }

  /// Reinterprets the fiat-mode bottom-slot raw (sats ↔ BTC) when the user
  /// changes the converter's Bitcoin display unit via the picker. Called
  /// synchronously from the picker handler **before** the global setting
  /// flips, so the screen rebuild sees a coherent (raw, display-unit) pair
  /// in one step. No effect in sats mode (the bottom slot there is always
  /// BTC regardless of the display setting).
  void migrateFiatBtcDisplay(BtcDisplayMode from, BtcDisplayMode to) {
    if (from == to) return;
    if (_fiat.active != ConverterSlot.bottom || _fiat.raw.isEmpty) return;
    final String nextRaw;
    if (to == BtcDisplayMode.btc) {
      // sats integer string → BTC decimal string
      nextRaw = Sats.satsToBtcRaw(int.tryParse(_fiat.raw) ?? 0);
    } else {
      // BTC decimal string → sats integer string
      final sats = Sats.btcRawToSats(_fiat.raw);
      nextRaw = sats == 0 ? '' : sats.toString();
    }
    final wasFiatMode = mode == ConverterMode.fiat;
    _fiat = _fiat.copyWith(raw: nextRaw, caret: nextRaw.length);
    onPersist?.call(ConverterMode.fiat, _fiat);
    if (wasFiatMode) notifyListeners();
  }
}
