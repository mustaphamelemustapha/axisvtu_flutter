import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const _themeModeKey = 'axis_theme_mode_v4'; // fresh key defaulting strictly to system

  ThemeMode _mode = ThemeMode.system;
  bool _loaded = false;

  ThemeController() {
    _load();
  }

  ThemeMode get mode => _mode;
  bool get isSystem => _mode == ThemeMode.system;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_themeModeKey);
      if (raw == 'light') {
        _mode = ThemeMode.light;
      } else if (raw == 'dark') {
        _mode = ThemeMode.dark;
      } else {
        _mode = ThemeMode.system;
      }
    } catch (_) {
      _mode = ThemeMode.system;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, _mode.name);
    } catch (_) {}
  }

  void setThemeMode(ThemeMode newMode) {
    _mode = newMode;
    notifyListeners();
    if (_loaded) {
      unawaited(_persist());
    }
  }

  void resetToSystem() {
    setThemeMode(ThemeMode.system);
  }

  void toggle({Brightness? currentBrightness}) {
    if (_mode == ThemeMode.system) {
      // Switch to the opposite of current brightness
      if (currentBrightness == Brightness.dark) {
        _mode = ThemeMode.light;
      } else {
        _mode = ThemeMode.dark;
      }
    } else if (_mode == ThemeMode.light) {
      _mode = ThemeMode.dark;
    } else {
      _mode = ThemeMode.system;
    }
    
    notifyListeners();
    if (_loaded) {
      unawaited(_persist());
    }
  }
}
