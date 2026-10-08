import 'package:flutter/services.dart';

/// Orientations the app allows by default. The home screen opts into
/// landscape; screens that are portrait-only (e.g. the converter) narrow
/// this to the portrait set while they're on screen and restore it on exit.
const List<DeviceOrientation> kDefaultOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Portrait-only orientations for screens that must stay vertical.
const List<DeviceOrientation> kPortraitOrientations = [
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
];

/// Landscape-only orientations for screens that must stay horizontal
/// (e.g. full-screen price mode).
const List<DeviceOrientation> kLandscapeOrientations = [
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];
