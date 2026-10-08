import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_enums.dart';
import '../../data/fiat.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/app_orientation.dart'
    show kDefaultOrientations, kPortraitOrientations;
import '../../services/app_haptics.dart';
import '../../state/state.dart';
import '../../theme/theme.dart';
import '../../widgets/number_pad.dart';
import 'converter_slot_view.dart';
import 'converter_controls.dart';
import 'converter_picker_sheets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Slot model
//
// Each mode has a "top" slot and a "bottom" slot. Their meaning:
//
//   Mode \ Slot      top                          bottom
//   ─────────────────────────────────────────────────────────────────────
//   fiat             fiat (currency)              Bitcoin (sats or BTC)
//   sats             sats                         BTC
//
// The user types into the active slot; the other is derived at render time
// from the live BTC price (fiat mode) or from a pure unit conversion (sats
// mode). The display unit of the Bitcoin-side slot is the converter's
// own [BtcDisplayMode] in fiat mode, and always BTC in sats mode.
// ─────────────────────────────────────────────────────────────────────────────

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  @override
  void initState() {
    super.initState();
    // The converter is portrait-only; the rest of the app (home screen) opts
    // into landscape. Lock to portrait on entry, restore on exit.
    SystemChrome.setPreferredOrientations(kPortraitOrientations);
    final converter = context.read<ConverterState>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) converter.seedPreferences();
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(kDefaultOrientations);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.watch<ConverterState>();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final currency = context.select<AppStateNotifier, Currency>(
      (a) => a.converterCurrency ?? a.currency,
    );
    final selectedBtcMode = context.select<AppStateNotifier, BtcDisplayMode>(
      (a) => a.converterBtcMode ?? a.btcDisplayMode,
    );

    final rate =
        context.select<LivePriceController, double?>(
          (c) => c.rates.forCurrency(currency),
        ) ??
        0;
    final isSatsMode = cs.mode == ConverterMode.sats;
    // In sats mode the bottom slot is always BTC. In fiat mode it follows
    // the converter's own display setting.
    final btcMode = isSatsMode ? BtcDisplayMode.btc : selectedBtcMode;

    // Derive both slots' raw strings. The active slot is verbatim; the other
    // is computed from it. Returns ('' '') when there's nothing useful to
    // show (rate unavailable in fiat mode, etc.).
    final raws = deriveRaws(
      mode: cs.mode,
      active: cs.active,
      raw: cs.raw,
      btcMode: btcMode,
      rate: rate,
    );

    return TickerMode(
      enabled: ModalRoute.of(context)?.isCurrent ?? true,
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerLow,
        appBar: AppBar(
          backgroundColor: scheme.surfaceContainerLow,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: BackButton(color: scheme.onSurfaceVariant),
          centerTitle: true,
          title: Text(
            l10n.homeConverter,
            style: AppTypography.title.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              ConverterModeToggle(
                mode: cs.mode,
                onChanged: (m) => cs.setMode(m),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: Align(
                  alignment: const Alignment(0, -0.65),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConverterSlotView(
                        unit: slotUnit(cs.mode, ConverterSlot.top, btcMode),
                        currency: currency,
                        raw: raws.top,
                        active: cs.active == ConverterSlot.top,
                        caret: cs.active == ConverterSlot.top ? cs.caret : 0,
                        onActivate: () =>
                            _activate(cs, ConverterSlot.top, rate, btcMode),
                        onCaretAt: (i) => cs.edit(caret: i),
                        onCopy: () => _copy(context, raws.top),
                        onLabelTap: isSatsMode
                            ? null
                            : () => _openCurrencyPicker(context),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const ConverterArrowStack(),
                      const SizedBox(height: AppSpacing.sm),
                      ConverterSlotView(
                        unit: slotUnit(cs.mode, ConverterSlot.bottom, btcMode),
                        currency: currency,
                        raw: raws.bottom,
                        active: cs.active == ConverterSlot.bottom,
                        caret: cs.active == ConverterSlot.bottom ? cs.caret : 0,
                        onActivate: () =>
                            _activate(cs, ConverterSlot.bottom, rate, btcMode),
                        onCaretAt: (i) => cs.edit(caret: i),
                        onCopy: () => _copy(context, raws.bottom),
                        onLabelTap: isSatsMode
                            ? null
                            : () => _openBtcUnitPicker(context),
                      ),
                    ],
                  ),
                ),
              ),
              // Leading-zero warning sits just above the keypad so it lands in
              // the user's eye-line as they tap the disabled '0' key. The
              // 20px slot is always reserved so toggling the warning doesn't
              // bump the keypad down.
              SizedBox(
                height: 20,
                child: cs.showLeadingZeroWarning
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.satsInputLeadingZeroWarning,
                          style: AppTypography.label.copyWith(
                            letterSpacing: 1.5,
                            color: scheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              NumberPad(
                showConfirm: false,
                showDecimal: activeAllowsDecimal(cs.mode, cs.active, btcMode),
                decimalLabel: localeDecimalSeparator,
                onInput: (v) => _onInput(cs, v, btcMode),
                onDelete: () => _onDelete(cs),
                onClear: () => _onClear(cs),
                onEnter: () {},
                isValid: false,
                isEmpty: cs.raw.isEmpty,
                zeroDisabled: leadingZeroBlocked(
                  cs.mode,
                  cs.active,
                  cs.raw,
                  btcMode,
                ),
                onZeroBlocked: () => cs.edit(warning: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onInput(ConverterState cs, String v, BtcDisplayMode btcMode) {
    final unit = slotUnit(cs.mode, cs.active, btcMode);
    final result = insertChar(cs.raw, cs.caret, v, unit);
    if (result == null) {
      // Insert rejected. The sats-side leading-zero rule still needs to
      // surface its warning even when the keypad's zeroDisabled gate didn't
      // fire (e.g. typing '0' at caret 0 with non-empty input).
      if (v == '0' &&
          unit == ConverterInputUnit.sats &&
          cs.caret == 0 &&
          cs.raw.isNotEmpty) {
        cs.edit(warning: true);
      }
      return;
    }
    cs.edit(raw: result.$1, caret: result.$2, warning: false);
  }

  void _onDelete(ConverterState cs) {
    if (cs.raw.isEmpty || cs.caret == 0) return;
    final next = cs.raw.substring(0, cs.caret - 1) + cs.raw.substring(cs.caret);
    cs.edit(raw: next, caret: cs.caret - 1);
  }

  void _onClear(ConverterState cs) {
    if (cs.raw.isEmpty) return;
    cs.edit(raw: '', caret: 0, warning: false);
  }

  /// Switches the active slot. Converts the existing raw into the new slot's
  /// unit so the displayed numbers don't visually jump, and the next
  /// keystroke appends to the now-active value.
  void _activate(
    ConverterState cs,
    ConverterSlot slot,
    double rate,
    BtcDisplayMode btcMode,
  ) {
    if (cs.active == slot) return;
    AppHaptics.selection();
    final isSatsMode = cs.mode == ConverterMode.sats;
    // Empty input, or fiat-mode without a rate, just flips the active slot.
    if (cs.raw.isEmpty || (!isSatsMode && rate <= 0)) {
      cs.edit(active: slot, warning: false);
      return;
    }
    final fromUnit = slotUnit(cs.mode, cs.active, btcMode);
    final toUnit = slotUnit(cs.mode, slot, btcMode);
    final sats = rawToSats(cs.raw, fromUnit, rate);
    final converted = satsToRaw(sats, toUnit, rate);
    cs.edit(active: slot, raw: converted, warning: false);
  }

  /// Opens the currency picker. Persists into the converter's own field —
  /// the home-screen currency and swipe ring stay untouched.
  Future<void> _openCurrencyPicker(BuildContext context) async {
    final notifier = context.read<AppStateNotifier>();
    final current = notifier.converterCurrency ?? notifier.currency;
    final picked = await showModalBottomSheet<Currency>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => ConverterCurrencySheet(current: current),
    );
    if (picked == null || picked == current) return;
    notifier.setConverterCurrency(picked);
  }

  /// Opens the Bitcoin display-unit picker. Migrates the live fiat-mode
  /// snapshot synchronously **before** persisting the new setting, so the
  /// next rebuild sees a coherent (raw, display-unit) pair in one step.
  /// No post-frame syncing, no race.
  Future<void> _openBtcUnitPicker(BuildContext context) async {
    final notifier = context.read<AppStateNotifier>();
    final cs = context.read<ConverterState>();
    final current = notifier.converterBtcMode ?? notifier.btcDisplayMode;
    final picked = await showModalBottomSheet<BtcDisplayMode>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (_) => ConverterBtcUnitSheet(current: current),
    );
    if (picked == null || picked == current) return;
    cs.migrateFiatBtcDisplay(current, picked);
    notifier.setConverterBtcMode(picked);
  }

  /// Copies the canonical numeric form of [raw] to the clipboard.
  Future<void> _copy(BuildContext context, String raw) async {
    if (raw.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: raw));
    AppHaptics.medium();
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.converterCopiedValue(raw)),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
