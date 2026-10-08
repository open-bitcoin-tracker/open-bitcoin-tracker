import 'package:flutter/material.dart';
import '../../../../data/app_enums.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/app_haptics.dart';
import '../../../../theme/theme.dart';

Future<BtcRange?> showRangePicker(
  BuildContext context, {
  required List<BtcRange> ranges,
  required String keyPrefix,
  required BtcRange current,
  required String Function(BuildContext, BtcRange) longLabel,
}) {
  return showDialog<BtcRange>(
    context: context,
    barrierColor: appDialogBarrierColor(context),
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx);
      return Dialog(
        elevation: 24,
        shadowColor: Colors.black,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.rangePickerLongTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final entry in ranges.asMap().entries) ...[
                        if (entry.key > 0)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: Theme.of(ctx).colorScheme.outlineVariant,
                          ),
                        _BtcRangeRow(
                          key: ValueKey('$keyPrefix-${entry.value.name}'),
                          label: longLabel(ctx, entry.value),
                          selected: entry.value == current,
                          onTap: () => Navigator.of(ctx).pop(entry.value),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _BtcRangeRow extends StatelessWidget {
  const _BtcRangeRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = context.palette;
    final radius = BorderRadius.circular(AppSpacing.radius);
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? p.bitcoinOrange : cs.outline,
                    width: 2,
                  ),
                  color: selected ? p.bitcoinOrange : Colors.transparent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.title.copyWith(
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
