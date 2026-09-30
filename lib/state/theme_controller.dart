import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const _themeModeKey = 'axis_theme_mode_v2'; // changed key to reset to system

  ThemeMode _mode = ThemeMode.system;
  bool _loaded = false;

  ThemeController() {
    _load();
  }

  ThemeMode get mode => _mode;

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
    } catch (_) {}
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, _mode.name);
    } catch (_) {}
  }

  void toggle() {
    // If it's system, we assume we toggle to something explicitly (e.g., light if system is currently dark, but we don't have context here)
    // We will just cycle: system -> light -> dark -> system
    if (_mode == ThemeMode.system) {
      _mode = ThemeMode.light;
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
