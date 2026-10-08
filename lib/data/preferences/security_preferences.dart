import 'package:flutter/foundation.dart';
import '../app_enums.dart';

@immutable
class SecurityPreferences {
  const SecurityPreferences({
    this.authMode = StacksAuthMode.off,
    this.lockTimeout = StacksLockTimeout.m5,
  });
  final StacksAuthMode authMode;
  final StacksLockTimeout lockTimeout;
  SecurityPreferences copyWith({
    StacksAuthMode? authMode,
    StacksLockTimeout? lockTimeout,
  }) => SecurityPreferences(
    authMode: authMode ?? this.authMode,
    lockTimeout: lockTimeout ?? this.lockTimeout,
  );
}
