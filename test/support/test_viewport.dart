import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Keep layout constraints and MediaQuery orientation on the same viewport.
void setTestViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
