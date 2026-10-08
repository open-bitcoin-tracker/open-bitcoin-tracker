import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/app_haptics.dart';
import '../../state/converter_state.dart';
import '../../theme/theme.dart';

/// Underlined segmented control: Fiat-BTC / Sats-BTC. The active mode shows
/// a bitcoin-orange underline; the inactive mode renders as plain label text.
class ConverterModeToggle extends StatefulWidget {
  const ConverterModeToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final ConverterMode mode;
  final ValueChanged<ConverterMode> onChanged;

  @override
  State<ConverterModeToggle> createState() => _ConverterModeToggleState();
}

class _ConverterModeToggleState extends State<ConverterModeToggle> {
  static const int _tabCount = 2;
  final List<GlobalKey> _tabKeys = List.generate(_tabCount, (_) => GlobalKey());
  final GlobalKey _stackKey = GlobalKey();

  List<Rect> _tabRects = const [];

  void _measureTabs() {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.hasSize) return;
    final rects = <Rect>[];
    for (final key in _tabKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final topLeft = stackBox.globalToLocal(box.localToGlobal(Offset.zero));
      rects.add(topLeft & box.size);
    }
    if (!_rectsEqual(rects, _tabRects)) {
      setState(() => _tabRects = rects);
    }
  }

  static bool _rectsEqual(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final palette = context.palette;
    final trackFill = palette.recessedSurface ?? cs.surfaceContainer;

    final selectedIndex = widget.mode == ConverterMode.fiat ? 0 : 1;
    final selectedRect = selectedIndex < _tabRects.length
        ? _tabRects[selectedIndex]
        : null;

    const trackPadding = 2.0;

    Widget tabSlot(int index, String label) {
      final selected = index == selectedIndex;
      return Expanded(
        child: Center(
          child: KeyedSubtree(
            key: _tabKeys[index],
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: selected
                  ? null
                  : () {
                      AppHaptics.light();
                      widget.onChanged(
                        index == 0 ? ConverterMode.fiat : ConverterMode.sats,
                      );
                    },
              child: Container(
                constraints: const BoxConstraints(minWidth: 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                alignment: Alignment.center,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  style: AppTypography.body.copyWith(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected
                        ? palette.bitcoinOrange
                        : cs.onSurfaceVariant,
                  ),
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ),
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureTabs());

    return Stack(
      children: [
        // Recessed track
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: trackFill,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(trackPadding),
          child: Stack(
            key: _stackKey,
            clipBehavior: Clip.none,
            children: [
              // Sliding pill
              if (selectedRect != null)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: selectedRect.left,
                  top: selectedRect.top,
                  width: selectedRect.width,
                  height: selectedRect.height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          offset: const Offset(0, 1),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              // Tab row on top of pill
              Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  tabSlot(0, l10n.converterModeBtcFiat),
                  tabSlot(1, l10n.converterModeBtcSats),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ConverterArrowStack extends StatelessWidget {
  const ConverterArrowStack({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.arrow_downward, size: 22, color: scheme.onSurfaceVariant),
        const SizedBox(width: 2),
        Icon(Icons.arrow_upward, size: 22, color: scheme.onSurfaceVariant),
      ],
    );
  }
}

/// Bottom-sheet currency picker. Single-select (unlike the multi-select ring
/// in the settings screen), because the converter has exactly one active
/// fiat side at a time.
