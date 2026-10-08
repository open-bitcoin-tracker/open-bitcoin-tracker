import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../theme/theme.dart';

// ---------------------------------------------------------------------------
// Empty-state Add Stack button with pulsing orange ripple rings.
// ---------------------------------------------------------------------------

class AddStackEmptyButton extends StatefulWidget {
  const AddStackEmptyButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<AddStackEmptyButton> createState() => _AddStackEmptyButtonState();
}

class _AddStackEmptyButtonState extends State<AddStackEmptyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return CustomPaint(
          painter: _RipplePainter(progress: _ctrl.value),
          child: child,
        );
      },
      child: FilledButton(
        onPressed: widget.onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.bitcoinOrange,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 64),
          textStyle: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radius),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
        ),
        child: Builder(
          builder: (context) => Text(AppLocalizations.of(context).homeAddStack),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.progress});
  final double progress;

  static const _ringCount = 3;

  @override
  void paint(Canvas canvas, Size size) {
    const baseRadius = AppSpacing.radius;
    const maxInset = 28.0;
    for (var i = 0; i < _ringCount; i++) {
      final t = (progress + i / _ringCount) % 1.0;
      final inset = -maxInset * t;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          inset,
          inset,
          size.width - inset * 2,
          size.height - inset * 2,
        ),
        Radius.circular(baseRadius - inset),
      );
      final opacity = (1.0 - t) * 0.15;
      final paint = Paint()
        ..color = AppColors.bitcoinOrange.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}
