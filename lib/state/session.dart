import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

class SessionController extends ChangeNotifier {
  SessionController();

  String? _token;
  Map<String, dynamic>? _user;
  bool _loading = false;
  String? _error;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _loading;
  String? get error => _error;
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
      _setError(null);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
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
      final data = await AuthService().register(
        fullName: name,
        email: email,
        phone: phone,
        password: password,
      );
      _token = _extractToken(data);
      _user = _extractUser(data);
      if (_token == null || _token!.isEmpty) {
        throw Exception('Registration failed. Missing token.');
      }
      if (!_hasMeaningfulProfile(_user)) {
        final fresh = await _fetchMe(_token!);
        if (fresh != null) _user = fresh;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('axisvtu_token', _token!);
      _setError(null);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
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
}
