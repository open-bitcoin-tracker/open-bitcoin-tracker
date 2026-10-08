import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../data/app_enums.dart';
import '../../data/fiat.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/app_haptics.dart';
import '../../theme/theme.dart';
import '../../state/converter_logic.dart';
import '../../widgets/blinking_caret.dart';

class ConverterSlotView extends StatelessWidget {
  const ConverterSlotView({
    super.key,
    required this.unit,
    required this.currency,
    required this.raw,
    required this.active,
    required this.caret,
    required this.onActivate,
    required this.onCaretAt,
    required this.onCopy,
    required this.onLabelTap,
  });

  final ConverterInputUnit unit;
  final Currency currency;
  final String raw;
  final bool active;
  final int caret;
  final VoidCallback onActivate;
  final ValueChanged<int> onCaretAt;
  final VoidCallback onCopy;
  final VoidCallback? onLabelTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    final String labelText;
    switch (unit) {
      case ConverterInputUnit.fiat:
        labelText = currency.code.toUpperCase();
      case ConverterInputUnit.sats:
        labelText = 'BITCOIN (${l10n.bitcoinDisplayModeSats.toUpperCase()})';
      case ConverterInputUnit.btc:
        labelText = 'BITCOIN (${l10n.bitcoinDisplayModeBtc.toUpperCase()})';
    }

    final symbol = currencySymbols[currency] ?? r'$';
    final String prefix;
    final String? suffix;
    switch (unit) {
      case ConverterInputUnit.fiat:
        prefix = symbolAfterAmount ? '' : symbol;
        suffix = symbolAfterAmount ? symbol : null;
      case ConverterInputUnit.sats:
      case ConverterInputUnit.btc:
        prefix = symbolAfterAmount ? '' : '₿';
        suffix = symbolAfterAmount ? '₿' : null;
    }

    // Sats raw is a pure digit string; everything else may contain a decimal
    // separator. formatFiatRaw handles both cleanly (it routes through
    // groupDigits for integer-only and splits/regroups around the '.').
    final display = unit == ConverterInputUnit.sats
        ? groupDigits(raw)
        : formatFiatRaw(raw);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabelRow(
          text: labelText,
          color: scheme.onSurfaceVariant,
          onTap: onLabelTap,
        ),
        const SizedBox(height: 4),
        _Card(
          prefix: prefix,
          suffix: suffix,
          value: display,
          raw: raw,
          caret: caret,
          active: active,
          onTap: onActivate,
          onLongPress: onCopy,
          onCaretAt: active ? onCaretAt : null,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatefulWidget {
  const _Card({
    required this.prefix,
    required this.value,
    required this.raw,
    required this.caret,
    required this.active,
    required this.onTap,
    this.onLongPress,
    this.onCaretAt,
    this.suffix,
  });

  final String prefix;
  // Formatted display: locale-grouped, with the locale's decimal separator
  // on fiat. What the user sees.
  final String value;
  // Canonical raw value: '.'-separated for fiat/BTC, digits-only for sats.
  // Used as the BlinkingCaret's keystroke signal.
  final String raw;
  // Caret position in [raw], in [0, raw.length]. Only meaningful when active.
  final int caret;
  final String? suffix;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  // Called when the user taps a character; places the caret to that char's
  // left. End-of-input is reachable via the card-tap InkWell.
  final ValueChanged<int>? onCaretAt;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  // Recognizer pool, one per per-character tap. Disposed in [dispose].
  final List<TapGestureRecognizer> _recognizers = [];

  TapGestureRecognizer _recognizerAt(int i, VoidCallback onTap) {
    while (_recognizers.length <= i) {
      _recognizers.add(TapGestureRecognizer());
    }
    _recognizers[i].onTap = onTap;
    return _recognizers[i];
  }

  void _trimRecognizers(int keepCount) {
    while (_recognizers.length > keepCount) {
      _recognizers.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = widget.active ? scheme.surfaceContainerHigh : scheme.surface;
    final fg = scheme.onSurface;
    const fontSize = 28.0;
    final numberStyle = TextStyle(
      fontFamily: AppTypography.sansFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      color: fg,
    );
    final localeSep = localeDecimalSeparator;
    // Caret is rendered with zero layout width so moving it between digits
    // doesn't shift the surrounding glyphs by the caret's 2px stroke. The
    // OverflowBox lets it paint outside its 0-width slot.
    final caretWidget = SizedBox(
      width: 0,
      height: fontSize * 1.2,
      child: OverflowBox(
        maxWidth: 2,
        alignment: Alignment.centerLeft,
        child: BlinkingCaret(
          color: fg,
          height: fontSize * 1.2,
          keystrokeSignal: '${widget.raw}|${widget.caret}',
        ),
      ),
    );

    // Build the value display. When active, a single shaped Text.rich
    // paragraph with per-char TextSpan tap recognizers (so spacing matches
    // the inactive Text(value) exactly). When inactive, plain Text — a tap
    // on the card activates this slot via the InkWell.
    final Widget valueWidget;
    if (widget.active && widget.value.isEmpty) {
      // Empty active side: 2px-wide caret so its stroke paints inside
      // layout bounds.
      valueWidget = SizedBox(
        width: 2,
        height: fontSize * 1.2,
        child: BlinkingCaret(
          color: fg,
          height: fontSize * 1.2,
          keystrokeSignal: '${widget.raw}|${widget.caret}',
        ),
      );
    } else if (widget.active) {
      final spans = <InlineSpan>[];
      final canTap = widget.onCaretAt != null;
      var rawConsumed = 0;
      var recognizerIdx = 0;
      void addCaretIfHere() {
        if (rawConsumed == widget.caret) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: caretWidget,
            ),
          );
        }
      }

      for (var i = 0; i < widget.value.length; i++) {
        final ch = widget.value[i];
        final isDigit = ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39;
        final isDecimal = ch == localeSep;
        // Group separators (commas, NBSPs, etc.) live between digits in the
        // formatted string but don't exist in raw, so they don't advance
        // the raw cursor.
        if (!isDigit && !isDecimal) {
          spans.add(TextSpan(text: ch));
          continue;
        }
        addCaretIfHere();
        final before = rawConsumed;
        spans.add(
          TextSpan(
            text: ch,
            recognizer: canTap
                ? _recognizerAt(
                    recognizerIdx++,
                    () => widget.onCaretAt!(before),
                  )
                : null,
          ),
        );
        rawConsumed += 1;
      }
      addCaretIfHere();
      _trimRecognizers(recognizerIdx);

      // FittedBox lets very long inputs shrink instead of clipping the
      // right edge of the card. Aligned left so the caret stays where the
      // user expects.
      valueWidget = Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(style: numberStyle, children: spans),
            maxLines: 1,
            softWrap: false,
          ),
        ),
      );
    } else if (widget.value.isNotEmpty) {
      valueWidget = Flexible(
        child: Text(
          widget.value,
          overflow: TextOverflow.ellipsis,
          style: numberStyle,
        ),
      );
    } else {
      // Inactive and empty: reserve the glyph's vertical space so the card
      // doesn't squash to label-height. (Sats-mode bottom card hits this
      // when there's no input — it has no prefix/suffix to hold the row open.)
      valueWidget = const SizedBox(width: 0, height: fontSize * 1.2);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.prefix.isNotEmpty) ...[
                  Text(widget.prefix, style: numberStyle),
                  const SizedBox(width: 4),
                ],
                valueWidget,
                if (widget.suffix != null) ...[
                  const SizedBox(width: 4),
                  Text(widget.suffix!, style: numberStyle),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Top-of-card label, optionally tappable. When [onTap] is null, renders as
/// plain text matching the previous look. When set, adds a small chevron
/// and becomes its own ink target. Both branches reserve the same bounding
/// box so cards don't shift when the chevron toggles.
class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.text, required this.color, this.onTap});

  final String text;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.label.copyWith(
      letterSpacing: 1.5,
      color: color,
      fontWeight: FontWeight.w500,
    );
    final body = Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 2,
        horizontal: 4,
      ).copyWith(left: 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(text, style: style),
          if (onTap != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 16, color: color),
          ] else
            const SizedBox(height: 16),
        ],
      ),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          AppHaptics.selection();
          onTap!();
        },
        child: body,
      ),
    );
  }
}
