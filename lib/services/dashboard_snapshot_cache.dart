import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DashboardSnapshotCache {
  const DashboardSnapshotCache._();

  static Future<void> _saveQueue = Future.value();

  static String? identityFromUser(Map<String, dynamic>? user) {
    if (user == null || user.isEmpty) return null;
    final candidates = <Object?>[
      user['id'],
      user['user_id'],
      user['email'],
      user['phone_number'],
      user['phone'],
      user['full_name'],
      user['name'],
    ];
    for (final candidate in candidates) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> load(String identity) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(identity));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<void> save(
    String identity, {
    Map<String, dynamic>? wallet,
    Map<String, dynamic>? accounts,
    List<Map<String, dynamic>>? transactions,
  }) async {
    _saveQueue = _saveQueue.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final current = await load(identity) ?? <String, dynamic>{};
      if (wallet != null) current['wallet'] = wallet;
      if (accounts != null) current['accounts'] = accounts;
      if (transactions != null) current['transactions'] = transactions;
      current['saved_at'] = DateTime.now().toIso8601String();
      await prefs.setString(_keyFor(identity), jsonEncode(current));
    });
    return _saveQueue;
  }

  static Future<void> clear(String identity) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFor(identity));
  }

  static String _keyFor(String identity) {
    final sanitized = identity
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'axisvtu_dashboard_snapshot_$sanitized';
  }
}
