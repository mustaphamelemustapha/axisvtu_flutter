import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class SessionController extends ChangeNotifier {
  SessionController();

  static const String lastIdentifierKey = 'axisvtu_last_identifier';

  String? _token;
  Map<String, dynamic>? _user;
  bool _loading = false;
  String? _error;
  bool _bootstrapped = false;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isBootstrapped => _bootstrapped;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

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
    } catch (_) {
      return null;
    }
  }

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('axisvtu_token');
    if (_token != null && _token!.isNotEmpty) {
      final fetched = await _fetchMe(_token!);
      if (fetched != null) {
        _user = fetched;
      } else {
        _token = null;
        _user = null;
      }
    }
    _bootstrapped = true;
    notifyListeners();
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('axisvtu_token', _token!);
      final trimmedIdentifier = email.trim();
      if (trimmedIdentifier.isNotEmpty) {
        await prefs.setString(lastIdentifierKey, trimmedIdentifier);
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

  Future<bool> register(
    String name,
    String email,
    String phone,
    String password,
  ) async {
    _setLoading(true);
    try {
      final normalizedEmail = email.trim();
      final data = await AuthService().register(
        fullName: name,
        email: normalizedEmail,
        phone: phone,
        password: password,
      );
      _token = _extractToken(data);
      _user = _extractUser(data);

      // Some backend builds create the account but do not return auth tokens.
      // Fallback: immediately sign in with submitted credentials.
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('axisvtu_token', _token!);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('axisvtu_token');
    _token = null;
    _user = null;
    notifyListeners();
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
