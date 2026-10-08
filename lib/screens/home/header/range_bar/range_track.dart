import 'package:flutter/material.dart';

import 'range_settings_button.dart';

/// Layout and moving pill for the range bar; chip callbacks belong to its owner.
class RangeBarTrack extends StatelessWidget {
  const RangeBarTrack({
    super.key,
    required this.horizontalPadding,
    required this.chipHeight,
    required this.trackFill,
    required this.stackKey,
    required this.pillRect,
    required this.selectedRect,
    required this.dragging,
    required this.motionActive,
    required this.motion,
    required this.verticalOffset,
    required this.onPillSettled,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onDragCancel,
    required this.chips,
    this.onSettings,
  });
  final double horizontalPadding;
  final double chipHeight;
  final Color trackFill;
  final GlobalKey stackKey;
  final Rect? pillRect;
  final Rect? selectedRect;
  final bool dragging;
  final bool motionActive;
  final Listenable motion;
  final double Function() verticalOffset;
  final VoidCallback onPillSettled;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;
  final GestureDragCancelCallback onDragCancel;
  final Widget chips;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const trackPadding = 2.0;
    const greyBarHeight = 28.0;
    const shadowBleedTop = 7.0;
    const shadowBleedBottom = 11.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        const settingsGap = 8.0;
        final settingsReserve = onSettings != null
            ? greyBarHeight + settingsGap + (36 - greyBarHeight) / 2
            : 0.0;
        final rightPadding = horizontalPadding + settingsReserve;
        final innerWidth =
            constraints.maxWidth -
            horizontalPadding -
            rightPadding -
            trackPadding * 2;
        final trackInset = (chipHeight - greyBarHeight) / 2;
        final circleTop = shadowBleedTop + trackInset;
        return Stack(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                shadowBleedTop,
                rightPadding,
                shadowBleedBottom,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    top: trackInset,
                    bottom: trackInset,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: trackFill,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: trackPadding,
                    ),
                    child: SizedBox(
                      width: innerWidth,
                      child: Stack(
                        key: stackKey,
                        clipBehavior: Clip.none,
                        children: [
                          if (pillRect != null)
                            AnimatedBuilder(
                              animation: motion,
                              builder: (context, child) => AnimatedPositioned(
                                duration: dragging || motionActive
                                    ? Duration.zero
                                    : const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                                onEnd: onPillSettled,
                                left: pillRect!.left,
                                top: pillRect!.top + verticalOffset(),
                                width: pillRect!.width,
                                height: pillRect!.height,
                                child: child!,
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: cs.surface,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: dragging ? 0.20 : 0.12,
                                          ),
                                          offset: const Offset(0, 1),
                                          blurRadius: dragging ? 6 : 3,
                                        ),
                                      ],
                                    ),
                                    child: const SizedBox.expand(),
                                  ),
                                ],
                              ),
                            ),
                          chips,
                          if (selectedRect != null)
                            AnimatedBuilder(
                              animation: motion,
                              builder: (context, child) => Positioned.fromRect(
                                rect: (pillRect ?? selectedRect!).translate(
                                  0,
                                  verticalOffset(),
                                ),
                                child: child!,
                              ),
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onHorizontalDragStart: onDragStart,
                                onHorizontalDragUpdate: onDragUpdate,
                                onHorizontalDragEnd: onDragEnd,
                                onHorizontalDragCancel: onDragCancel,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (onSettings != null)
              Positioned(
                right: horizontalPadding + (36 - greyBarHeight) / 2,
                top: circleTop,
                width: greyBarHeight,
                height: greyBarHeight,
                child: RangeSettingsButton(
                  onTap: onSettings!,
                  fill: trackFill,
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        );
      },
    );
  }
}
