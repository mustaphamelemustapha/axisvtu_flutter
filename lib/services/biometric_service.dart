import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  static final _auth = LocalAuthentication();
  static const _secureStorage = FlutterSecureStorage();
  static const _appLockKey = 'app_biometric_lock';
  static const _securePinKey = 'secure_transaction_pin';

  /// Check if the user has enabled biometric app lock.
  static Future<bool> get isAppLockEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_appLockKey) ?? false;
  }

  /// Enable or disable biometric app lock.
  static Future<void> setAppLockEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockKey, value);
    if (!value) {
      await deletePin(); // Clean up PIN if disabled
    }
  }

  /// Securely store the transaction PIN.
  static Future<void> savePin(String pin) async {
    await _secureStorage.write(key: _securePinKey, value: pin);
  }

  /// Retrieve the stored transaction PIN.
  static Future<String?> getPin() async {
    return await _secureStorage.read(key: _securePinKey);
  }

  /// Delete the stored transaction PIN.
  static Future<void> deletePin() async {
    await _secureStorage.delete(key: _securePinKey);
  }

  /// Check if the device hardware supports biometrics.
  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Check if biometrics are currently enrolled and available to use.
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Trigger the biometric authentication prompt.
  static Future<bool> authenticate({String reason = 'Please authenticate to access your account'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true, // Prefer Face/Touch ID over device PIN
        persistAcrossBackgrounding: true, // Keep auth alive if app is minimized briefly
      );
    } on PlatformException {
      return false;
    }
  }
}
