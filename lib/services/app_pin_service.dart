import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPinService {
  static const _pinKeyPrefix = 'axis_app_pin_v2';
  static const _securePinKeyPrefix = 'axis_app_pin_secure_v2';
  static const _legacyScopedPinKey = 'axis_app_pin_v1';
  static const _legacyScopedSecurePinKey = 'axis_app_pin_secure_v1';
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
  static String _scopeKey = 'global';

  static String _scopedKey(String prefix) => '${prefix}_$_scopeKey';

  static String _sanitizeScope(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    if (raw.isEmpty) return 'global';
    final normalized = raw.replaceAll(RegExp(r'[^a-z0-9._@-]'), '_');
    return normalized.isEmpty ? 'global' : normalized;
  }

  static void setUserScope(String? identity) {
    final next = _sanitizeScope(identity);
    if (next == _scopeKey) return;
    _scopeKey = next;
    _cachedPin = null;
    _hydrated = false;
  }

  static String _sanitizePin(String pin) {
    final digits = pin.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 4) return '';
    return digits;
  }

  static Future<void> _persistPinEverywhere(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    _cachedPin = pin;
    await prefs.setString(_scopedKey(_pinKeyPrefix), pin);
    try {
      await _secureStorage.write(key: _scopedKey(_securePinKeyPrefix), value: pin);
    } catch (_) {
      // Keep SharedPreferences as fallback when secure storage is unavailable.
    }
  }

  static Future<void> _hydrateIfNeeded() async {
    if (_hydrated) return;
    _hydrated = true;

    final prefs = await SharedPreferences.getInstance();
    String resolved = '';
    final scopedSecureKey = _scopedKey(_securePinKeyPrefix);
    final scopedPrefsKey = _scopedKey(_pinKeyPrefix);

    try {
      resolved = _sanitizePin(await _secureStorage.read(key: scopedSecureKey) ?? '');
    } catch (_) {
      resolved = '';
    }

    if (resolved.isEmpty) {
      resolved = _sanitizePin(prefs.getString(scopedPrefsKey) ?? '');
    }

    // Migrate from older non-scoped keys on first read.
    if (resolved.isEmpty) {
      try {
        resolved = _sanitizePin(
          await _secureStorage.read(key: _legacyScopedSecurePinKey) ?? '',
        );
      } catch (_) {
        resolved = '';
      }
    }

    if (resolved.isEmpty) {
      resolved = _sanitizePin(prefs.getString(_legacyScopedPinKey) ?? '');
    }

    if (resolved.isEmpty) {
      resolved = _sanitizePin(prefs.getString(_legacyPinKey) ?? '');
    }

    if (resolved.isEmpty) {
      resolved = _sanitizePin(prefs.getString(_legacyPinKeyAlt) ?? '');
    }

    if (resolved.isNotEmpty) {
      await _persistPinEverywhere(resolved);
      await prefs.remove(_legacyScopedPinKey);
      await prefs.remove(_legacyPinKey);
      await prefs.remove(_legacyPinKeyAlt);
      try {
        await _secureStorage.delete(key: _legacyScopedSecurePinKey);
      } catch (_) {
        // no-op
      }
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
    await prefs.remove(_scopedKey(_pinKeyPrefix));
    await prefs.remove(_legacyScopedPinKey);
    await prefs.remove(_legacyPinKey);
    await prefs.remove(_legacyPinKeyAlt);
    try {
      await _secureStorage.delete(key: _scopedKey(_securePinKeyPrefix));
      await _secureStorage.delete(key: _legacyScopedSecurePinKey);
    } catch (_) {
      // no-op
    }
  }
}
