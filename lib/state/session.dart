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

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('axisvtu_token');
    if (_token != null && _token!.isNotEmpty) {
      try {
        final data = await AuthService(token: _token).me();
        _user = data['user'] ?? data;
      } catch (_) {
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
      _token = data['access_token'] ?? data['token'] ?? data['data']?['access_token'];
      _user = data['user'] ?? data['data']?['user'];
      if (_token == null || _token!.isEmpty) {
        throw Exception('Login failed. Missing token.');
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

  Future<bool> register(String name, String email, String phone, String password) async {
    _setLoading(true);
    try {
      final data = await AuthService().register(
        fullName: name,
        email: email,
        phone: phone,
        password: password,
      );
      _token = data['access_token'] ?? data['token'] ?? data['data']?['access_token'];
      _user = data['user'] ?? data['data']?['user'];
      if (_token == null || _token!.isEmpty) {
        throw Exception('Registration failed. Missing token.');
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

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }
}
