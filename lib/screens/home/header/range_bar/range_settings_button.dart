import 'package:flutter/material.dart';
import '../../../../services/app_haptics.dart';

class RangeSettingsButton extends StatelessWidget {
  const RangeSettingsButton({
    super.key,
    required this.onTap,
    required this.fill,
    required this.color,
  });

  final VoidCallback onTap;
  final Color fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppHaptics.light();
        onTap();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        child: Center(child: Icon(Icons.tune, size: 16, color: color)),
      ),
    );
  }
}
