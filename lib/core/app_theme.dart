import 'package:flutter/foundation.dart';

/// App-wide dark/light mode flag for the Servis (calibration) UI.
///
/// [CalColors] reads `AppTheme.instance.isDark` directly (not via
/// InheritedWidget/Theme.of), so any widget tree that should react to a
/// theme change must listen to [darkNotifier] and rebuild — see
/// `CalibrationScreen`'s use of `ValueListenableBuilder`.
class AppTheme {
  AppTheme._();

  static final AppTheme instance = AppTheme._();

  final ValueNotifier<bool> darkNotifier = ValueNotifier<bool>(false);

  bool get isDark => darkNotifier.value;

  void setDark(bool value) {
    if (darkNotifier.value == value) return;
    darkNotifier.value = value;
  }
}
