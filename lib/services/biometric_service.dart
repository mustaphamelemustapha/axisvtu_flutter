import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricAvailability {
  final bool supported;
  final bool canCheck;
  final bool hasEnrolled;
  final String? error;

  const BiometricAvailability({
    required this.supported,
    required this.canCheck,
    required this.hasEnrolled,
    this.error,
  });

  bool get ready => supported && canCheck;
}

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

  /// Returns a full readiness snapshot for profile toggle messaging.
  static Future<BiometricAvailability> getAvailability() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      List<BiometricType> enrolled = const [];
      try {
        enrolled = await _auth.getAvailableBiometrics();
      } on PlatformException {
        enrolled = const [];
      }
      return BiometricAvailability(
        supported: supported,
        canCheck: canCheck,
        hasEnrolled: enrolled.isNotEmpty,
      );
    } on PlatformException catch (e) {
      return BiometricAvailability(
        supported: false,
        canCheck: false,
        hasEnrolled: false,
        error: e.message,
      );
    } catch (e) {
      return BiometricAvailability(
        supported: false,
        canCheck: false,
        hasEnrolled: false,
        error: e.toString(),
      );
    }
  }

  /// Trigger the biometric authentication prompt.
  static Future<bool> authenticate({
    String reason = 'Please authenticate to access your account',
  }) async {
    try {
      // ignore: deprecated_member_use
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on PlatformException {
      return false;
    }
  }
}
