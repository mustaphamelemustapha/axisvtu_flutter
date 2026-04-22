import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const _themeModeKey = 'axis_theme_mode_v1';

  ThemeMode _mode = ThemeMode.dark;
  bool _loaded = false;

  ThemeController() {
    _load();
  }

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_themeModeKey);
      if (raw == 'light') {
        _mode = ThemeMode.light;
      } else if (raw == 'dark') {
        _mode = ThemeMode.dark;
      }
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, isDark ? 'dark' : 'light');
    } catch (_) {}
  }

  void toggle() {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    if (_loaded) {
      unawaited(_persist());
    }
  }
}
