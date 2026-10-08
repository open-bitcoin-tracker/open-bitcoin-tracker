import 'package:flutter/foundation.dart';
import '../app_enums.dart';

@immutable
class AppearancePreferences {
  const AppearancePreferences({
    this.theme = AppTheme.system,
    this.darkVariant = DarkVariant.blue,
    this.lightVariant = LightVariant.cream,
    this.language = LanguagePref.system,
    this.btcDisplayMode = BtcDisplayMode.btc,
  });
  final AppTheme theme;
  final DarkVariant darkVariant;
  final LightVariant lightVariant;
  final LanguagePref language;
  final BtcDisplayMode btcDisplayMode;
  AppearancePreferences copyWith({
    AppTheme? theme,
    DarkVariant? darkVariant,
    LightVariant? lightVariant,
    LanguagePref? language,
    BtcDisplayMode? btcDisplayMode,
  }) => AppearancePreferences(
    theme: theme ?? this.theme,
    darkVariant: darkVariant ?? this.darkVariant,
    lightVariant: lightVariant ?? this.lightVariant,
    language: language ?? this.language,
    btcDisplayMode: btcDisplayMode ?? this.btcDisplayMode,
  );
}
