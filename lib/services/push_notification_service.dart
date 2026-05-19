import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import '../config.dart';
import '../state/session.dart';

class PushNotificationService {
  static const _pushNotificationsKey = 'axis_profile_push_notifications_v1';

  static Future<void> initialize(SessionController session) async {
    // Only support Android push notifications for now, as requested
    if (!Platform.isAndroid) {
      debugPrint("[PushNotification] Disabled for non-Android platforms.");
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final isEnabled = prefs.getBool(_pushNotificationsKey) ?? true;

      if (!session.isAuthenticated) {
        return;
      }

      if (!isEnabled) {
        // If disabled, ensure we wipe the FCM token from the backend
        debugPrint("[PushNotification] Notification option is disabled. Wiping token from backend.");
        await syncTokenWithBackend("", session.token!);
        return;
      }

      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      
      final messaging = FirebaseMessaging.instance;
      
      // Request permissions (important for iOS)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get the token
        final fcmToken = await messaging.getToken();
        
        if (fcmToken != null && session.isAuthenticated) {
          await syncTokenWithBackend(fcmToken, session.token!);
        }

        // Listen for token refreshes
        messaging.onTokenRefresh.listen((newToken) async {
          final currentPrefs = await SharedPreferences.getInstance();
          final currentEnabled = currentPrefs.getBool(_pushNotificationsKey) ?? true;
          if (session.isAuthenticated && currentEnabled) {
            syncTokenWithBackend(newToken, session.token!);
          }
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('Got a message whilst in the foreground!');
          debugPrint('Message data: ${message.data}');
          if (message.notification != null) {
            debugPrint('Message also contained a notification: ${message.notification}');
          }
        });
      }
    } catch (e) {
      debugPrint("Failed to initialize Firebase Messaging: $e");
    }
  }

  static Future<void> syncTokenWithBackend(String fcmToken, String authToken) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/auth/fcm-token');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      );

      if (response.statusCode == 200) {
        debugPrint("Successfully synced FCM token with backend.");
      } else {
        debugPrint("Failed to sync FCM token. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error syncing FCM token: $e");
    }
  }
}
