import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../state/session.dart';
import '../widgets/interactive_notification_banner.dart';

class PushNotificationService {
  static const _pushNotificationsKey = 'axis_profile_push_notifications_v1';
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initialize(SessionController session) async {
    // Support Android and iOS push notifications
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint("[PushNotification] Disabled for unsupported platforms.");
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

      // Get the token
      final fcmToken = await messaging.getToken();
      
      if (fcmToken != null && session.isAuthenticated) {
        await syncTokenWithBackend(fcmToken, session.token!);
        try {
          await messaging.subscribeToTopic('all_users');
          debugPrint("[PushNotification] Subscribed to broadcast topic: all_users");
        } catch (topicExc) {
          debugPrint("[PushNotification] Failed to subscribe to topic: $topicExc");
        }
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
        
        // Always refresh balance when a foreground push is received (wallet funding, tx success, etc)
        if (session.isAuthenticated) {
          session.refreshBalance();
        }

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          final context = navigatorKey.currentContext;
          if (context != null && context.mounted) {
            final title = message.notification?.title ?? 'MELE DATA';
            final body = message.notification?.body ?? '';
            final soundType = message.data['sound_type'] as String?;
            InteractiveNotificationBanner.show(
              context,
              title: title,
              message: body,
              soundType: soundType,
            );
          }
        }
      });
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
