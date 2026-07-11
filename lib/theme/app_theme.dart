import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppAccent { purple, blue, teal, orange, green, indigo }

const Map<AppAccent, MaterialColor> _kAccentSwatches = {
  AppAccent.purple: Colors.deepPurple,
  AppAccent.blue: Colors.blue,
  AppAccent.teal: Colors.teal,
  AppAccent.orange: Colors.deepOrange,
  AppAccent.green: Colors.green,
  AppAccent.indigo: Colors.indigo,
};

MaterialColor accentSwatchFor(AppAccent accent) => _kAccentSwatches[accent]!;

const Map<AppAccent, String> kAccentLabels = {
  AppAccent.purple: 'Purple',
  AppAccent.blue: 'Blue',
  AppAccent.teal: 'Teal',
  AppAccent.orange: 'Orange',
  AppAccent.green: 'Green',
  AppAccent.indigo: 'Indigo',
};

const String _kAccentPrefKey = 'app_theme_accent';
const String _kModePrefKey = 'app_theme_mode';

// Per-user theme preference (accent color + light/dark/system), persisted
// locally via SharedPreferences. A single app-wide ChangeNotifier singleton
// so any screen can read the current accent synchronously (AppTheme.accent)
// without threading state through constructors, and MaterialApp rebuilds via
// an AnimatedBuilder listening to this notifier.
class AppTheme extends ChangeNotifier {
  AppTheme._();
  static final AppTheme instance = AppTheme._();

  AppAccent _accentKey = AppAccent.purple;
  ThemeMode _mode = ThemeMode.system;

  AppAccent get accentKey => _accentKey;
  ThemeMode get mode => _mode;

  static MaterialColor get accent => _kAccentSwatches[instance._accentKey]!;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final accentName = prefs.getString(_kAccentPrefKey);
    if (accentName != null) {
      _accentKey = AppAccent.values.firstWhere(
          (a) => a.name == accentName, orElse: () => AppAccent.purple);
    }
    final modeName = prefs.getString(_kModePrefKey);
    if (modeName != null) {
      _mode = ThemeMode.values.firstWhere(
          (m) => m.name == modeName, orElse: () => ThemeMode.system);
    }
    notifyListeners();
  }

  Future<void> setAccent(AppAccent accent) async {
    if (_accentKey == accent) return;
    _accentKey = accent;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccentPrefKey, accent.name);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModePrefKey, mode.name);
  }
}
