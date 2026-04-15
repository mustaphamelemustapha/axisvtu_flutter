import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPinService {
  static const _pinKey = 'axis_app_pin_v1';
  static const _securePinKey = 'axis_app_pin_secure_v1';
  static const _legacyPinKey = 'axis_transaction_pin_v1';
  static const _legacyPinKeyAlt = 'transaction_pin';

  static const _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static String? _cachedPin;
  static bool _hydrated = false;

  static String _sanitizePin(String pin) {
    final digits = pin.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 4) return '';
    return digits;
  }

  static Future<void> _persistPinEverywhere(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    _cachedPin = pin;
    await prefs.setString(_pinKey, pin);
    try {
      await _secureStorage.write(key: _securePinKey, value: pin);
    } catch (_) {
      // Keep SharedPreferences as fallback when secure storage is unavailable.
    }
  }

  static Future<void> _hydrateIfNeeded() async {
    if (_hydrated) return;
    _hydrated = true;

    final prefs = await SharedPreferences.getInstance();
    String resolved = '';

    try {
      resolved = _sanitizePin(await _secureStorage.read(key: _securePinKey) ?? '');
    } catch (_) {
      resolved = '';
    }

    if (resolved.isEmpty) {
      resolved = _sanitizePin(prefs.getString(_pinKey) ?? '');
    }

    if (resolved.isEmpty) {
      resolved = _sanitizePin(prefs.getString(_legacyPinKey) ?? '');
    }

    if (resolved.isEmpty) {
      resolved = _sanitizePin(prefs.getString(_legacyPinKeyAlt) ?? '');
    }

    if (resolved.isNotEmpty) {
      await _persistPinEverywhere(resolved);
      await prefs.remove(_legacyPinKey);
      await prefs.remove(_legacyPinKeyAlt);
    } else {
      _cachedPin = null;
    }
  }

  static Future<String> _readPin() async {
    await _hydrateIfNeeded();
    return _cachedPin ?? '';
  }

  static Future<bool> hasPin() async {
    return (await _readPin()).length == 4;
  }

  static Future<void> savePin(String pin) async {
    final normalized = _sanitizePin(pin);
    if (normalized.length != 4) {
      throw ArgumentError('PIN must be exactly 4 digits.');
    }
    await _persistPinEverywhere(normalized);
  }

  static Future<bool> verifyPin(String pin) async {
    final expected = await _readPin();
    final entered = _sanitizePin(pin);
    if (expected.length != 4 || entered.length != 4) return false;
    return expected == entered;
  }

  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedPin = null;
    await prefs.remove(_pinKey);
    await prefs.remove(_legacyPinKey);
    await prefs.remove(_legacyPinKeyAlt);
    try {
      await _secureStorage.delete(key: _securePinKey);
    } catch (_) {
      // no-op
    }
  }
}
