import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DashboardSnapshotCache {
  const DashboardSnapshotCache._();

  static final Map<String, Map<String, dynamic>> _memoryCache = {};

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

  static Map<String, dynamic>? loadSync(String identity) {
    return _memoryCache[identity];
  }

  static Future<Map<String, dynamic>?> load(String identity) async {
    if (_memoryCache.containsKey(identity)) {
      return _memoryCache[identity];
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(identity));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final result = decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        _memoryCache[identity] = result;
        return result;
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
    List<Map<String, dynamic>>? announcements,
    Map<String, dynamic>? referrals,
  }) async {
    // Instantly update the static memory cache synchronously so the next frame is 100% accurate without latency
    final currentMem = _memoryCache[identity] ?? <String, dynamic>{};
    if (wallet != null) currentMem['wallet'] = wallet;
    if (accounts != null) currentMem['accounts'] = accounts;
    if (transactions != null) currentMem['transactions'] = transactions;
    if (announcements != null) currentMem['announcements'] = announcements;
    if (referrals != null) currentMem['referrals'] = referrals;
    currentMem['saved_at'] = DateTime.now().toIso8601String();
    _memoryCache[identity] = currentMem;

    _saveQueue = _saveQueue.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final current = await load(identity) ?? <String, dynamic>{};
      if (wallet != null) current['wallet'] = wallet;
      if (accounts != null) current['accounts'] = accounts;
      if (transactions != null) current['transactions'] = transactions;
      if (announcements != null) current['announcements'] = announcements;
      if (referrals != null) current['referrals'] = referrals;
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
