import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeProvider extends ChangeNotifier {
  ThemeModeProvider(this._prefs)
      : _mode = _prefs.getString(_key) == 'dark' ? ThemeMode.dark : ThemeMode.light;

  static const _key = 'themeMode';
  final SharedPreferences _prefs;
  ThemeMode _mode;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  void toggle() {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    _prefs.setString(_key, isDark ? 'dark' : 'light');
    notifyListeners();
  }
}
