import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/app_enums.dart';
import '../../../../services/app_haptics.dart';
import '../../../../state/state.dart';
import '../../../../theme/theme.dart';
import 'range_chip.dart';
import 'range_labels.dart';
import 'range_picker.dart';
import 'range_track.dart';
import 'range_slot.dart';

class RangeBar extends StatefulWidget {
  const RangeBar({
    super.key,
    required this.range,
    required this.onRange,
    required this.chartColor,
    this.onSettings,
  });

  final BtcRange range;
  final ValueChanged<BtcRange> onRange;
  final Color chartColor;
  // When non-null, a circular settings button is shown to the right of the
  // grey track, vertically aligned with it. Null hides the button.
  final VoidCallback? onSettings;

  @override
  State<RangeBar> createState() => _RangeBarState();
}

class _RangeBarState extends State<RangeBar> with TickerProviderStateMixin {
  // One key per range chip (in row order) so we can measure the selected chip's
  // laid-out rect and slide a single shared pill to it. The settings button is
  // not a selectable chip, so it has no key.
  static const int _rangeChipCount = 5;
  final List<GlobalKey> _chipKeys = List.generate(
    _rangeChipCount,
    (_) => GlobalKey(),
  );

  // Drives the vertical "nudge" the pill makes when the user swipes up/down on
  // it to cycle the range within a slot (1D→2D→…). The pill kicks a few pixels
  // in the swipe direction and springs back, so the gesture has visible
  // feedback. _nudgeDir is -1 for an up-swipe, +1 for down.
  late final AnimationController _nudgeController =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed ||
            status == AnimationStatus.dismissed) {
          setState(() {}); // lets build() re-evaluate _syncHintBob
        }
      });
  late final Listenable _motion = Listenable.merge([
    _nudgeController,
    _hintBobController,
  ]);
  double _currentVerticalOffset() => _dragging
      ? 0
      : _nudgeController.isAnimating
      ? _nudgeOffset
      : (_hintBobController.isAnimating ? _hintBobOffset : 0);
  int _nudgeDir = 0;
  // Peak vertical travel of the nudge, in logical pixels.
  static const double _nudgeAmplitude = 6;

  // Kicks the pill in [dir] (-1 up, +1 down) and springs it back. Called when a
  // swipe cycles the slot's range; the slot itself doesn't move, so this is the
  // only motion that signals the change.
  void _nudgePill(int dir) {
    _hintBobController.stop();
    _nudgeDir = dir;
    _nudgeController.forward(from: 0);
    setState(() {});
  }

  // Current vertical offset of the nudge: a single up-then-back arc (sine) so it
  // eases out and returns to rest, scaled by direction and amplitude.
  double get _nudgeOffset =>
      _nudgeDir * _nudgeAmplitude * math.sin(_nudgeController.value * math.pi);

  // Drives the idle hint animation that bobs the pill up and down while the
  // swipe-chip tip is visible. Runs a slow repeating sine wave; paused when
  // the hint is dismissed, the pill is being dragged, or a real nudge fires.
  late final AnimationController _hintBobController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  static const double _hintBobAmplitude = 5;

  // Current vertical offset from the idle hint bob. Produces a full sine cycle
  // (up → rest → down → rest) so the motion looks like a gentle invitation.
  double get _hintBobOffset =>
      _hintBobAmplitude * math.sin(_hintBobController.value * 2 * math.pi);

  // Latches to true the first time the user selects a non-All range while the
  // hint hasn't yet been dismissed. Once set it never clears (within the
  // session), so tapping back to All — or navigating to a full-screen page —
  // does NOT hide the hint. Only a vertical swipe on the pill dismisses it.
  bool _hintTriggered = false;

  // Starts or stops the hint bob depending on whether the tip is currently
  // visible. Called from build whenever the hint-dismissed flag changes.
  void _syncHintBob({required bool hintVisible}) {
    if (hintVisible && !_dragging && !_nudgeController.isAnimating) {
      if (!_hintBobController.isAnimating) {
        _hintBobController.value = 0;
        _hintBobController.repeat();
      }
    } else {
      _hintBobController.stop();
    }
  }

  @override
  void dispose() {
    _visualSelectTimer?.cancel();
    _nudgeController.dispose();
    _hintBobController.dispose();
    super.dispose();
  }

  // Key for the Stack the pill is positioned within — its render box is the
  // coordinate frame we resolve each chip's rect into.
  final GlobalKey _stackKey = GlobalKey();

  // Each range chip's rect, in the Stack's local coordinates, indexed by slot.
  // Empty until the first post-frame measurement lands; the pill is hidden
  // until then so it never flashes at the wrong spot. We measure every chip
  // (not just the selected one) so a drag can map the finger position to a slot
  // and snap to it.
  List<Rect> _chipRects = const [];

  // Per-slot width of just the label text (no chip padding), supplied by the
  // build. Used to highlight a hovered slot only once the dragged pill's center
  // is actually over the range's name — not as soon as it enters the padded
  // chip box. Empty until the first build populates it.
  List<double> _chipLabelWidths = const [];

  // While the user is dragging the pill, this holds its free left edge (Stack
  // coordinates); null when not dragging. During a drag the pill follows the
  // finger un-animated; on release it snaps to the nearest slot.
  double? _dragLeft;
  // Slot the drag started on, and the slot the pill currently overlaps. The
  // hovered slot's label is highlighted as the pill passes over it, and on
  // release we commit that slot's range if it differs from where we started.
  int _dragStartIndex = -1;
  int _dragHoverIndex = -1;

  bool get _dragging => _dragLeft != null;

  // The slot whose label shows the selected styling (bold + chart color +
  // flick-hint chevrons). It lags the real selected slot: when a tap picks a
  // new range, the pill starts gliding immediately and the label's selected
  // styling fades in shortly after — partway through the glide, not only on
  // arrival — so the highlight feels responsive while still trailing the pill.
  // -1 until the first build resolves the initial selection. Drags bypass this
  // and highlight the hovered slot directly.
  int _visualSelectedIndex = -1;

  // Pending flip of [_visualSelectedIndex] onto a newly tapped slot. Fired a
  // short way into the pill's glide so the label fade overlaps the pill's
  // motion instead of waiting for it to finish (the old onEnd-only behavior
  // left the highlight feeling late). The pill's onEnd is still a backstop in
  // case the glide is interrupted before this fires.
  Timer? _visualSelectTimer;
  // The slot the pending [_visualSelectTimer] will flip to; -1 when no flip is
  // scheduled. Lets a build detect when the tap target changed mid-glide and
  // reschedule for the new slot instead of firing on a stale one.
  int _visualSelectTarget = -1;
  // How long after a tap the label starts adopting the selected styling. Kept
  // well under the pill's 260ms glide so the fade and the slide finish at about
  // the same time.
  static const Duration _visualSelectLead = Duration(milliseconds: 90);

  // Re-measures every chip and, if any moved, updates [_chipRects] so the pill
  // can slide to the selected slot (and a drag can resolve slot boundaries).
  // Runs after every frame the bar lays out (selection change, label-width
  // change, text-scale change). Skipped mid-drag so measurement churn doesn't
  // fight the finger-driven position.
  void _measureChips() {
    if (_dragging) return;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || !stackBox.hasSize) return;
    final rects = <Rect>[];
    for (final key in _chipKeys) {
      final chipBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (chipBox == null || !chipBox.hasSize) return; // not laid out yet
      final topLeft = stackBox.globalToLocal(
        chipBox.localToGlobal(Offset.zero),
      );
      rects.add(topLeft & chipBox.size);
    }
    if (!_rectsEqual(rects, _chipRects)) {
      setState(() => _chipRects = rects);
    }
  }

  static bool _rectsEqual(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // The label's horizontal span within slot [index]'s chip rect: the label is
  // centered in the chip, so this is a [labelWidth]-wide band around the chip
  // center. Used to decide when the dragged pill's center has "reached the name"
  // and the slot should flip to its selected styling.
  ({double left, double right})? _labelSpan(int index) {
    if (index < 0 ||
        index >= _chipRects.length ||
        index >= _chipLabelWidths.length) {
      return null;
    }
    final center = _chipRects[index].center.dx;
    final half = _chipLabelWidths[index] / 2;
    return (left: center - half, right: center + half);
  }

  // Slot whose label band horizontally contains [centerX], or -1 if the pill's
  // center sits in the padding/gap between names. Drives the live hover
  // highlight: a slot only goes "selected" once the pill center is over its
  // name, not merely inside its (padded) chip box.
  int _slotForLabel(double centerX) {
    for (var i = 0; i < _chipRects.length; i++) {
      final span = _labelSpan(i);
      if (span != null && centerX >= span.left && centerX <= span.right) {
        return i;
      }
    }
    return -1;
  }

  void _onPillDragStart(int selectedIndex, DragStartDetails _) {
    if (_chipRects.isEmpty) return;
    _hintBobController.stop();
    // Drop any pending tap-driven flip; the drag highlights the hovered slot
    // directly and the timer would otherwise fire on the old tap target.
    _visualSelectTimer?.cancel();
    _visualSelectTarget = -1;
    setState(() {
      _dragStartIndex = selectedIndex;
      _dragHoverIndex = selectedIndex;
      _dragLeft = _chipRects[selectedIndex].left;
    });
  }

  void _onPillDragUpdate(DragUpdateDetails d) {
    final left = _dragLeft;
    if (left == null || _chipRects.isEmpty) return;
    final width = _chipRects[_dragStartIndex].width;
    // Clamp the pill within the span of the first and last range chips so it
    // can't be dragged off the track or under the settings button.
    final minLeft = _chipRects.first.left;
    final maxLeft = _chipRects.last.right - width;
    final next = (left + d.delta.dx).clamp(minLeft, maxLeft);
    // Highlight a slot only once the pill's center is over that slot's name; in
    // the padding/gap between names keep the last highlighted slot rather than
    // flipping early or going blank.
    final overLabel = _slotForLabel(next + width / 2);
    final hover = overLabel >= 0 ? overLabel : _dragHoverIndex;
    setState(() {
      _dragLeft = next;
      if (hover != _dragHoverIndex) {
        _dragHoverIndex = hover;
        AppHaptics.selection();
      }
    });
  }

  void _onPillDragEnd(DragEndDetails _) {
    final landedIndex = _dragHoverIndex;
    final startIndex = _dragStartIndex;
    setState(() {
      _dragLeft = null;
      _dragStartIndex = -1;
      _dragHoverIndex = -1;
      // The pill is already at the finger (the landed slot), so style that slot
      // selected immediately — there's no glide to lag behind, and leaving the
      // visual index on the start slot would flicker it bold during the snap.
      if (landedIndex >= 0) _visualSelectedIndex = landedIndex;
    });
    // Commit the new range only if the pill ended on a different slot. The
    // AnimatedPositioned then snaps the pill onto that slot's measured rect.
    if (landedIndex >= 0 && landedIndex != startIndex) {
      AppHaptics.light();
      _selectSlot(landedIndex);
    }
  }

  void _onPillDragCancel() {
    setState(() {
      _dragLeft = null;
      _dragStartIndex = -1;
      _dragHoverIndex = -1;
    });
  }

  // Activates the range mounted in slot [index] (row order: days, weeks,
  // months, years overflow slots, then All). Reads each overflow slot's current
  // value from the notifier so a drag selects exactly what tapping that chip
  // would.
  void _selectSlot(int index) {
    final app = context.read<AppStateNotifier>();
    final range = index < RangeSlot.values.length
        ? RangeSlot.values[index].current(app)
        : BtcRange.all;
    widget.onRange(range);
  }

  @override
  Widget build(BuildContext context) {
    final range = widget.range;
    final onRange = widget.onRange;
    final chartColor = widget.chartColor;
    final onSettings = widget.onSettings;
    // Select just the four overflow slots instead of watching the whole
    // notifier — the bar sits in the per-tick header subtree, so an app-state
    // notification (converter keystroke, hint dismissal, …) must not drag it
    // into the rebuild.
    final swipeHintDismissed = context.select<AppStateNotifier, bool>(
      (a) => a.swipeChipHintDismissed,
    );
    // Latch: once the user has been on a non-All range the hint is "active".
    // Selecting All again (or navigating away) must NOT clear it — only a
    // vertical swipe on the pill dismisses the hint.
    if (widget.range != BtcRange.all && !swipeHintDismissed) {
      _hintTriggered = true;
    }
    final hintVisible =
        _hintTriggered && !swipeHintDismissed && widget.range != BtcRange.all;
    _syncHintBob(hintVisible: hintVisible);
    final daysOverflowSlot = context.select<AppStateNotifier, BtcRange>(
      (a) => a.daysOverflowQuickRange,
    );
    final weeksOverflowSlot = context.select<AppStateNotifier, BtcRange>(
      (a) => a.weeksOverflowQuickRange,
    );
    final overflowSlot = context.select<AppStateNotifier, BtcRange>(
      (a) => a.overflowQuickRange,
    );
    final monthsOverflowSlot = context.select<AppStateNotifier, BtcRange>(
      (a) => a.monthsOverflowQuickRange,
    );
    final textScaler = MediaQuery.textScalerOf(context);
    // 1.4 matches the Inter body line-height (AppTypography.body height: 1.4).
    // Floor at 24 so the icon on overflow chips doesn't overflow at textScale=1.
    final labelRow = math.max<double>(textScaler.scale(14) * 1.4, 24);
    // Inner horizontal padding of the recessed track around the chip row.
    // Expected chip content height (text + vertical padding) — used to center
    // the grey track within the chip row via trackInset.
    final chipHeight = labelRow + 16;
    // Width floor for each chip's label. Two reasons we need this:
    //   1. Selecting a chip flips its weight to w600, which is wider than the
    //      regular weight — so without a floor the chip grows on selection
    //      and `spaceBetween` shifts every neighbor.
    //   2. The overflow chip's label cycles through 1Y..15Y and the digit
    //      count changes its width.
    // Measured against the actual rendered (bold) style so it tracks the
    // system font scale.
    final boldStyle = AppTypography.body.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    double labelWidth(String label) => maxRangeLabelWidth(
      context: context,
      labels: [label],
      style: boldStyle,
      textScaler: textScaler,
    );
    const slots = RangeSlot.values;
    final currentRanges = [
      daysOverflowSlot,
      weeksOverflowSlot,
      monthsOverflowSlot,
      overflowSlot,
    ];
    final labelWidths = [
      for (final slot in slots)
        maxRangeLabelWidth(
          context: context,
          labels: [for (final r in slot.ranges) btcRangeLabel(context, r)],
          style: boldStyle,
          textScaler: textScaler,
        ),
    ];
    // Layout: <days slot>, <weeks slot>, <months slot>, <years slot>, All. Both overflow slots
    // are user-customizable (long-press to change) and All sits at the end. The row distributes chips across the available width with
    // spaceBetween, but when natural chip widths exceed the screen (large
    // system text), it scrolls horizontally so every chip stays reachable.
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final horizontalPadding = isLandscape ? 32.0 : AppSpacing.md;
    // The whole row sits inside a recessed, pill-shaped track (segmented-control
    // look). The track's inner padding (trackPadding, above) keeps the selected
    // pill and the first/last labels off its rounded edge.
    final cs = Theme.of(context).colorScheme;
    final trackFill = context.palette.recessedSurface ?? cs.surfaceContainer;

    // Which of the five range chips is selected (row order: days, weeks,
    // months, years, All); -1 if none, which hides the sliding pill.
    final selectedIndex = range == BtcRange.all
        ? 4
        : currentRanges.indexOf(range);

    // Per-slot label-text widths (row order), so a drag highlights a slot only
    // once the pill's center is over the name. The first four are each slot's
    // cycling-label floor; the All slot uses its own label width (without the
    // +18 chip padding the chip reserves for tap area).
    final allLabelWidth = labelWidth(btcRangeLabel(context, BtcRange.all));
    _chipLabelWidths = [...labelWidths, allLabelWidth];

    // Build each range chip wrapped in an Expanded slot. The measurement key
    // goes on the chip itself (not the slot), so the pill hugs the chip's
    // label-sized box rather than the full slot width.
    Widget rangeSlot(int index, Widget chip) => Expanded(
      child: Center(
        child: KeyedSubtree(key: _chipKeys[index], child: chip),
      ),
    );

    // Pill geometry: while dragging it follows the finger (free left, fixed at
    // the start slot's width); otherwise it sits on the selected chip's rect.
    // A vertical nudge (from a swipe that cycles the slot's range) shifts top by
    // _nudgeOffset; it's not applied while dragging.
    final selectedRect =
        (selectedIndex >= 0 && selectedIndex < _chipRects.length)
        ? _chipRects[selectedIndex]
        : null;
    final Rect? pillRect;
    if (_dragging &&
        _dragStartIndex >= 0 &&
        _dragStartIndex < _chipRects.length) {
      final base = _chipRects[_dragStartIndex];
      pillRect = Rect.fromLTWH(_dragLeft!, base.top, base.width, base.height);
    } else if (selectedRect != null) {
      // Real nudge (user swipe) takes priority over the idle hint bob.
      pillRect = selectedRect;
    } else {
      pillRect = null;
    }
    // Seed the lagged visual index on the first build, and snap it straight to
    // the selection whenever there's no pill glide to wait for — either the
    // initial paint (-1), or there's no rendered pill (rects not measured yet,
    // or nothing selected) so the pill's onEnd will never fire to catch it up.
    if (_visualSelectedIndex == -1 || pillRect == null) {
      _visualSelectTimer?.cancel();
      _visualSelectTarget = -1;
      _visualSelectedIndex = selectedIndex;
    } else if (!_dragging && _visualSelectedIndex != selectedIndex) {
      // A tap moved the selection and the pill is gliding to it. Flip the label
      // to selected a short way into the glide so the fade overlaps the slide
      // rather than starting only when the pill lands. Reschedule if the target
      // changed (a second tap mid-glide) so the timer never fires on a stale
      // slot.
      if (_visualSelectTarget != selectedIndex) {
        _visualSelectTimer?.cancel();
        _visualSelectTarget = selectedIndex;
        final target = selectedIndex;
        _visualSelectTimer = Timer(_visualSelectLead, () {
          _visualSelectTarget = -1;
          if (!mounted || _dragging) return;
          setState(() => _visualSelectedIndex = target);
        });
      }
    }
    // The hovered slot's label is highlighted while dragging; otherwise the
    // *visually* selected slot is — which lags the real selection until the
    // pill finishes gliding (the pill below tracks selectedIndex directly, so
    // it moves first and the label flips bold/orange only on arrival).
    final highlightIndex = _dragging ? _dragHoverIndex : _visualSelectedIndex;
    bool slotSelected(int index) => index == highlightIndex;
    // Combined vertical offset for the selected chip's content (label).
    // Real nudge wins; idle hint bob fills in when actively running.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureChips());
    return RangeBarTrack(
      horizontalPadding: horizontalPadding,
      chipHeight: chipHeight,
      trackFill: trackFill,
      onSettings: onSettings,
      stackKey: _stackKey,
      pillRect: pillRect,
      selectedRect: selectedRect,
      dragging: _dragging,
      motionActive:
          _nudgeController.isAnimating || _hintBobController.isAnimating,
      motion: _motion,
      verticalOffset: _currentVerticalOffset,
      onPillSettled: () {
        if (!_dragging && _visualSelectedIndex != selectedIndex) {
          setState(() => _visualSelectedIndex = selectedIndex);
        }
      },
      onDragStart: (d) => _onPillDragStart(selectedIndex, d),
      onDragUpdate: _onPillDragUpdate,
      onDragEnd: _onPillDragEnd,
      onDragCancel: _onPillDragCancel,
      chips: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          for (var index = 0; index < slots.length; index++)
            rangeSlot(
              index,
              RangeBarChip(
                label: btcRangeLabel(context, currentRanges[index]),
                selected: slotSelected(index),
                onTap: () => slotSelected(index)
                    ? _showSlotPicker(context, slots[index])
                    : onRange(currentRanges[index]),
                onLongPress: () => _showSlotPicker(context, slots[index]),
                onSwipeUp: () {
                  _nudgePill(-1);
                  _stepSlot(context, slots[index], 1);
                },
                onSwipeDown: () {
                  _nudgePill(1);
                  _stepSlot(context, slots[index], -1);
                },
                motion: slotSelected(index) ? _motion : null,
                animatedOffset: slotSelected(index)
                    ? _currentVerticalOffset
                    : null,
                rollDirection: _nudgeDir == 0 ? 1 : _nudgeDir,
                chartColor: chartColor,
                minLabelWidth: labelWidths[index],
              ),
            ),
          rangeSlot(
            4,
            RangeBarChip(
              label: btcRangeLabel(context, BtcRange.all),
              selected: slotSelected(4),
              onTap: () => onRange(BtcRange.all),
              chartColor: chartColor,
              minLabelWidth: allLabelWidth + 18,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSlotPicker(BuildContext context, RangeSlot slot) async {
    final app = context.read<AppStateNotifier>();
    final picked = await showRangePicker(
      context,
      ranges: slot.ranges,
      keyPrefix: slot.keyPrefix,
      current: slot.current(app),
      longLabel: slot.longLabel,
    );
    if (picked != null) {
      slot.update(app, picked);
      widget.onRange(picked);
    }
  }

  void _stepSlot(BuildContext context, RangeSlot slot, int step) {
    final app = context.read<AppStateNotifier>();
    app.dismissSwipeChipHint();
    final current = slot.current(app);
    final next = slot.cycle(current, step);
    if (next == current) return;
    slot.update(app, next);
    widget.onRange(next);
  }
}
