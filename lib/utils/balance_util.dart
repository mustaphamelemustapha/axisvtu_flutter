import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/session.dart';
import '../services/dashboard_snapshot_cache.dart';

double getUserBalance(BuildContext context) {
  final session = context.read<SessionController>();
  final user = session.user;
  
  final dashboardKey = DashboardSnapshotCache.identityFromUser(user) ?? session.token ?? '';
  if (dashboardKey.isNotEmpty) {
    final memCached = DashboardSnapshotCache.loadSync(dashboardKey);
    if (memCached != null && memCached['wallet'] != null) {
      final walletData = memCached['wallet'];
      if (walletData is Map) {
        final direct = walletData['balance'];
        if (direct != null) return double.tryParse(direct.toString()) ?? 0.0;
        
        final nested = walletData['wallet'];
        if (nested is Map) {
          return double.tryParse((nested['balance'] ?? 0).toString()) ?? 0.0;
        }
      } else if (walletData is num) {
        return walletData.toDouble();
      } else if (walletData is String) {
        return double.tryParse(walletData) ?? 0.0;
      }
    }
  }

  if (user == null) return 0.0;
  
  final direct = user['balance'];
  if (direct != null) return double.tryParse(direct.toString()) ?? 0.0;

  final nested = user['wallet'];
  if (nested is Map) {
    return double.tryParse((nested['balance'] ?? 0).toString()) ?? 0.0;
  }
  return 0.0;
}
