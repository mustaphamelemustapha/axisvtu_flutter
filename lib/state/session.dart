import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../services/config_service.dart';
import '../services/push_notification_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SessionController extends ChangeNotifier {
  SessionController();

  static const String lastIdentifierKey = 'axisvtu_last_identifier';
  static const String _tokenKey = 'axisvtu_secure_token_v1';
  static const String _biometricTokenKey = 'axisvtu_biometric_token_v1';
  static const String _securityPrefKey = 'axisvtu_security_preference_v1';
  
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String? _token;
  Map<String, dynamic>? _user;
  bool _loading = false;
  String? _error;
  bool _bootstrapped = false;
  
  bool _updateRequired = false;
  String _playStoreUrl = '';
  String _appStoreUrl = '';

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isBootstrapped => _bootstrapped;
  bool get updateRequired => _updateRequired;
  String get playStoreUrl => _playStoreUrl;
  String get appStoreUrl => _appStoreUrl;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isAdmin {
    final role = (_user?['role'] ?? '').toString().toLowerCase();
    return role == 'admin' || role == 'superadmin';
  }

  String? _securityPreference;
  String? get securityPreference => _securityPreference;
  bool get hasSecurityPreference => _securityPreference != null;

  bool _isLocked = false;
  bool get isLocked => _isLocked;

  void lock() {
    if (_securityPreference == 'max') {
      _isLocked = true;
      notifyListeners();
    }
  }

  void unlock() {
    _isLocked = false;
    notifyListeners();
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  String? _extractToken(Map<String, dynamic> data) {
    return data['access_token'] ??
        data['token'] ??
        _asMap(data['data'])?['access_token'] ??
        _asMap(data['data'])?['token'];
  }

  Map<String, dynamic>? _extractUser(Map<String, dynamic> data) {
    return _asMap(data['user']) ?? _asMap(_asMap(data['data'])?['user']);
  }

  bool _hasMeaningfulProfile(Map<String, dynamic>? user) {
    if (user == null || user.isEmpty) return false;
    final fullName = (user['full_name'] ?? user['name'] ?? '')
        .toString()
        .trim();
    final email = (user['email'] ?? '').toString().trim();
    return fullName.isNotEmpty || email.isNotEmpty;
  }

  Future<Map<String, dynamic>?> _fetchMe(String token) async {
    try {
      final data = await AuthService(token: token).me();
      return _asMap(data['user']) ?? data;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        rethrow; // Definitive auth failure
      }
      rethrow; // Propagate network/server errors
    } catch (e) {
      rethrow;
    }
  }

  bool _isVersionOutdated(String current, String minimum) {
    try {
      final v1 = current.split('.').map(int.parse).toList();
      final v2 = minimum.split('.').map(int.parse).toList();
      for (var i = 0; i < v1.length && i < v2.length; i++) {
        if (v1[i] < v2[i]) return true;
        if (v1[i] > v2[i]) return false;
      }
      return v1.length < v2.length;
    } catch (e) {
      return false; // If parsing fails, don't force update to be safe
    }
  }

  Future<void> bootstrap() async {
    if (_bootstrapped && isAuthenticated && !_updateRequired) return;
    
    try {
      // 1. Fetch config and check app version FIRST
      try {
        final config = await ConfigService.fetchAppConfig();
        _playStoreUrl = config['play_store_url'] ?? '';
        _appStoreUrl = config['app_store_url'] ?? '';
        
        final minVersionStr = config['min_app_version'] as String?;
        if (minVersionStr != null && minVersionStr.isNotEmpty) {
          final packageInfo = await PackageInfo.fromPlatform();
          final currentVersion = packageInfo.version;
          _updateRequired = _isVersionOutdated(currentVersion, minVersionStr);
        }
      } catch (e) {
        debugPrint('[Session] Failed to fetch app config: $e');
      }

      // If update is required, we don't necessarily stop bootstrap, but we do set the flag.
      // We can continue bootstrapping auth so they stay logged in underneath.
      
      try {
        _token = await _secureStorage.read(key: _tokenKey);
      } catch (e) {
        debugPrint('[Session] Secure storage read failed: $e');
        _token = null;
      }
      if (_token != null && _token!.isNotEmpty) {
        final fetched = await _fetchMe(_token!);
        if (fetched != null) {
          _user = fetched;
        }
      }

      // 3. Load Security Preference
      final prefs = await SharedPreferences.getInstance();
      _securityPreference = prefs.getString(_securityPrefKey);
    } catch (e) {
      // Definitive 401/403
      if (e is ApiException && (e.statusCode == 401 || e.statusCode == 403)) {
        await logout();
      }
      // We ignore network errors during bootstrap to allow the app to open offline
    } finally {
      _bootstrapped = true;
      notifyListeners();
      
      // Attempt to initialize Push Notifications (will do nothing until uncommented)
      PushNotificationService.initialize(this);
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      final data = await AuthService().login(email: email, password: password);
      _token = _extractToken(data);
      _user = _extractUser(data);
      if (_token == null || _token!.isEmpty) {
        throw Exception('Login failed. Missing token.');
      }
      if (!_hasMeaningfulProfile(_user)) {
        final fresh = await _fetchMe(_token!);
        if (fresh != null) _user = fresh;
      }
      
      await _secureStorage.write(key: _tokenKey, value: _token!);
      
      // If biometrics were previously enabled, keep the token fresh.
      final hasBio = await _secureStorage.read(key: _biometricTokenKey) != null;
      if (hasBio) {
        await _secureStorage.write(key: _biometricTokenKey, value: _token!);
      }
      
      final prefs = await SharedPreferences.getInstance();
      final trimmedIdentifier = email.trim();
      if (trimmedIdentifier.isNotEmpty) {
        await prefs.setString(lastIdentifierKey, trimmedIdentifier);
      }
      _setError(null);
      notifyListeners();
      
      // Sync token upon fresh login
      PushNotificationService.initialize(this);
      
      return true;
    } catch (e) {
      _setError(_friendlyError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(
    String name,
    String email,
    String phone,
    String password,
    {String? referralCode}
  ) async {
    _setLoading(true);
    try {
      final normalizedEmail = email.trim();
      final data = await AuthService().register(
        fullName: name,
        email: normalizedEmail,
        phone: phone,
        password: password,
        referralCode: referralCode,
      );
      _token = _extractToken(data);
      _user = _extractUser(data);

      if (_token == null || _token!.isEmpty) {
        final loginData = await AuthService().login(
          email: normalizedEmail,
          password: password,
        );
        _token = _extractToken(loginData);
        _user = _extractUser(loginData) ?? _user;
      }
      if (_token == null || _token!.isEmpty) {
        throw Exception(
          'Registration completed, but automatic sign-in failed. Please login now.',
        );
      }
      if (!_hasMeaningfulProfile(_user)) {
        final fresh = await _fetchMe(_token!);
        if (fresh != null) _user = fresh;
      }

      await _secureStorage.write(key: _tokenKey, value: _token!);

      final prefs = await SharedPreferences.getInstance();
      final preferredIdentifier = normalizedEmail.isNotEmpty
          ? normalizedEmail
          : phone.trim();
      if (preferredIdentifier.isNotEmpty) {
        await prefs.setString(lastIdentifierKey, preferredIdentifier);
      }
      _setError(null);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_friendlyError(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
    } catch (e) {
      debugPrint('[Session] Secure storage delete failed: $e');
    }
    _token = null;
    _user = null;
    _securityPreference = null;
    _isLocked = false;
    notifyListeners();
  }

  Future<void> setSecurityPreference(String pref) async {
    _securityPreference = pref;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_securityPrefKey, pref);
    notifyListeners();
  }

  /// Saves the current session token specifically for biometric quick-login.
  Future<void> enableBiometrics() async {
    if (_token == null || _token!.isEmpty) return;
    try {
      await _secureStorage.write(key: _biometricTokenKey, value: _token!);
      debugPrint('[Session] Biometric token saved.');
    } catch (e) {
      debugPrint('[Session] Failed to save biometric token: $e');
    }
  }

  /// Removes any saved biometric quick-login credentials.
  Future<void> disableBiometrics() async {
    try {
      await _secureStorage.delete(key: _biometricTokenKey);
      debugPrint('[Session] Biometric token deleted.');
    } catch (e) {
      debugPrint('[Session] Failed to delete biometric token: $e');
    }
  }

  /// Attempts to restore the session using the saved biometric token.
  Future<bool> loginWithBiometrics() async {
    try {
      final bioToken = await _secureStorage.read(key: _biometricTokenKey);
      if (bioToken == null || bioToken.isEmpty) {
        debugPrint('[Session] No biometric token found.');
        return false;
      }

      try {
        // 1. Attempt to fetch profile to verify token & hydrate UI
        final user = await _fetchMe(bioToken);
        if (user != null) {
          _token = bioToken;
          _user = user;
          await _secureStorage.write(key: _tokenKey, value: _token!);
          _setError(null);
          notifyListeners();
          return true;
        }
      } on ApiException catch (e) {
        if (e.statusCode == 401 || e.statusCode == 403) {
          // Genuine session expiration
          debugPrint('[Session] Biometric token is expired.');
          _token = null;
          await disableBiometrics();
          return false;
        }
        // Network error (408, 503, etc.) - return true IF we can fallback to cached state
        if (_user != null) {
          debugPrint('[Session] Network error, using cached user.');
          _token = bioToken;
          _setError(null);
          notifyListeners();
          return true;
        }
        
        // No cached user and network failed - we can't sign in right now, but DON'T disable biometrics
        _token = null;
        _setError(_friendlyError(e));
        return false;
      }

      // 2. Fallback for successful but null-user response
      if (_user != null) {
        _token = bioToken;
        notifyListeners();
        return true;
      }

      _token = null;
      return false;
    } catch (e) {
      debugPrint('[Session] loginWithBiometrics unexpected error: $e');
      _token = null;
      _setError(_friendlyError(e));
      return false;
    }
  }


  void updateUser(Map<String, dynamic> user) {
    _user = user;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  String _friendlyError(Object error) {
    final raw = error.toString().trim();
    if (raw.startsWith('Exception: ')) {
      return raw.substring('Exception: '.length);
    }
    if (raw.startsWith('ApiException(')) {
      final idx = raw.indexOf(':');
      if (idx != -1 && idx + 1 < raw.length) {
        return raw.substring(idx + 1).trim();
      }
    }
    return raw;
  }
}
