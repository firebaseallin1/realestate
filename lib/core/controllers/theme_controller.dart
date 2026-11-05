import 'package:flutter/material.dart';

/// ThemeController manages the application's theme state.
/// Allows toggling between Sage Mode (Default) and Light Mode reactively.
class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._internal();

  factory ThemeController() => instance;

  ThemeController._internal();

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }
}

