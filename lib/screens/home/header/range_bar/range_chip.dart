import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../services/app_haptics.dart';
import '../../../../theme/theme.dart';

class RangeBarChip extends StatelessWidget {
  const RangeBarChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.chartColor,
    this.onLongPress,
    this.onSwipeUp,
    this.onSwipeDown,
    this.contentOffsetY = 0,
    this.motion,
    this.animatedOffset,
    this.rollDirection = 1,
    this.minLabelWidth,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color chartColor;
  final VoidCallback? onLongPress;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final double contentOffsetY;
  final Listenable? motion;
  final double Function()? animatedOffset;
  final int rollDirection;
  final double? minLabelWidth;

  @override
  Widget build(BuildContext context) {
    return _Chip(
      label: label,
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      onSwipeUp: onSwipeUp,
      onSwipeDown: onSwipeDown,
      contentOffsetY: contentOffsetY,
      motion: motion,
      animatedOffset: animatedOffset,
      rollDirection: rollDirection,
      compact: true,
      selectedColor: chartColor,
      minLabelWidth: minLabelWidth,
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.onSwipeUp,
    this.onSwipeDown,
    this.contentOffsetY = 0,
    this.motion,
    this.animatedOffset,
    this.rollDirection = 1,
    this.compact = false,
    this.selectedColor,
    this.minLabelWidth,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  // Each accumulated _swipeStep of vertical drag fires one of these. Up = drag
  // toward smaller y (negative dy), down = drag toward larger y. Used by the
  // overflow range slot to cycle through years without opening the picker.
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  // Vertical translation (logical px) applied to the chip's label + chevrons.
  // The parent feeds the same swipe-nudge offset it applies to the sliding pill
  // here, so the pill and its content move together while a swipe cycles ranges.
  final double contentOffsetY;
  final Listenable? motion;
  final double Function()? animatedOffset;
  // Direction the label slides in when it changes during a swipe: +1 for a
  // down-swipe (new label enters from below), -1 for an up-swipe (enters from
  // above). Mirrors the live-price RollingNumber direction, but vertical.
  final int rollDirection;
  final bool compact;
  // When set, overrides the selected-state text/icon color (defaults to
  // cs.onSurface). Used to tint the active chip orange to match the chart.
  final Color? selectedColor;
  // Width floor for the label text. The overflow chip cycles through labels of
  // varying widths (1Y..15Y) and uses this to keep its size stable so the row
  // doesn't reflow on each cycle.
  final double? minLabelWidth;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  static const double _swipeStep = 24;
  // How long the selected styling (label color/weight, flick-hint chevrons)
  // takes to fade in or out when this chip gains or loses selection.
  static const Duration _selectFade = Duration(milliseconds: 200);
  // Cumulative dy since drag-start. The chip uses a vertical-drag recognizer
  // so it wins the gesture arena against the enclosing scroll view — without
  // that, drags on the chip would also feed the outer scroll and trigger
  // overscroll bounce. Once the user drags well past the chip's bounds we
  // stop firing (treats it as "they meant to scroll, just got the chip"),
  // though by then the scroll view has already lost the arena.
  double _accumDy = 0;
  bool _outsideChip = false;

  void _handleDragStart(DragStartDetails _) {
    _accumDy = 0;
    _outsideChip = false;
  }

  void _handleDragUpdate(DragUpdateDetails d) {
    if (widget.onSwipeUp == null && widget.onSwipeDown == null) return;
    if (_outsideChip) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      final local = box.globalToLocal(d.globalPosition);
      final size = box.size;
      if (local.dx < -16 ||
          local.dy < -16 ||
          local.dx > size.width + 16 ||
          local.dy > size.height + 16) {
        _outsideChip = true;
        return;
      }
    }
    _accumDy += d.delta.dy;
    while (_accumDy <= -_swipeStep) {
      _accumDy += _swipeStep;
      if (widget.onSwipeUp != null) {
        AppHaptics.selection();
        widget.onSwipeUp!();
      }
    }
    while (_accumDy >= _swipeStep) {
      _accumDy -= _swipeStep;
      if (widget.onSwipeDown != null) {
        AppHaptics.selection();
        widget.onSwipeDown!();
      }
    }
  }

  void _handleDragEnd(DragEndDetails _) {
    _accumDy = 0;
    _outsideChip = false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = widget.selected
        ? (widget.selectedColor ?? cs.onSurface)
        : cs.onSurfaceVariant;
    final hasSwipe = widget.onSwipeUp != null || widget.onSwipeDown != null;
    Widget core = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppHaptics.light();
        widget.onTap();
      },
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              AppHaptics.medium();
              widget.onLongPress!();
            },
      child: Container(
        constraints: BoxConstraints(
          minWidth: math.max(36, (widget.minLabelWidth ?? 0) + 1),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 10 : AppSpacing.md,
          vertical: 8,
        ),
        // The selected-state pill background is drawn by the shared sliding
        // pill behind the row (see _RangeBarState.build), not per-chip — so the
        // chip itself is transparent and only styles its label.
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: widget.motion ?? const AlwaysStoppedAnimation<double>(0),
          builder: (context, child) => Transform.translate(
            offset: Offset(
              0,
              (widget.animatedOffset?.call() ?? widget.contentOffsetY) - 1,
            ),
            child: child,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: _selectFade,
                curve: Curves.easeOut,
                style: AppTypography.body.copyWith(
                  fontSize: 14,
                  fontWeight: widget.selected ? FontWeight.w600 : null,
                  color: activeColor,
                ),
                child: AnimatedSwitcher(
                  duration: AppSpacing.motionDuration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.center,
                    children: [...previous, ?current],
                  ),
                  transitionBuilder: (child, anim) {
                    final isIncoming = child.key == ValueKey(widget.label);
                    final begin = Offset(
                      0,
                      (isIncoming ? 1.0 : -1.0) * widget.rollDirection * 0.6,
                    );
                    return FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: begin,
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    widget.label,
                    key: ValueKey(widget.label),
                    textAlign: TextAlign.center,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!hasSwipe) return core;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        _EagerVerticalDragRecognizer:
            GestureRecognizerFactoryWithHandlers<_EagerVerticalDragRecognizer>(
              () => _EagerVerticalDragRecognizer(),
              (instance) {
                instance
                  ..dragStartBehavior = DragStartBehavior.down
                  ..onStart = _handleDragStart
                  ..onUpdate = _handleDragUpdate
                  ..onEnd = _handleDragEnd
                  ..onCancel = () {
                    _accumDy = 0;
                    _outsideChip = false;
                  };
              },
            ),
      },
      child: core,
    );
  }
}

// Vertical-drag recognizer that wins the gesture arena as soon as the pointer
// moves vertically (rather than waiting for slop), so the enclosing scroll
// view doesn't also receive the deltas — which would otherwise bounce the
// page. Crucially, it does NOT claim on pointer-down: the inner tap
// recognizer needs to win plain taps, and would lose if this one accepted
// eagerly on every touch.
//
// We only claim when the motion is predominantly vertical (|dy| > |dx|).
// Without this check a real finger's horizontal pill-drag has enough vertical
// jitter that dy != 0 fires first and this recognizer steals the arena,
// preventing the pill from being dragged on physical devices.
class _EagerVerticalDragRecognizer extends VerticalDragGestureRecognizer {
  @override
  void handleEvent(PointerEvent event) {
    super.handleEvent(event);
    if (event is PointerMoveEvent &&
        event.delta.dy != 0 &&
        event.delta.dy.abs() > event.delta.dx.abs()) {
      resolve(GestureDisposition.accepted);
    }
  }
}
