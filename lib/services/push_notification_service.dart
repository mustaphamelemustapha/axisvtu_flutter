import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'api_client.dart';
import '../config.dart';
import '../state/session.dart';

class PushNotificationService {
  static Future<void> initialize(SessionController session) async {
    // -------------------------------------------------------------------------
    // IMPORTANT: Firebase Setup Required!
    // 1. Create a Firebase project at console.firebase.google.com
    // 2. Add an Android app with package name: com.axisvtu.app
    // 3. Download google-services.json and place it in android/app/
    // 4. Run: flutter pub add firebase_core firebase_messaging
    // 5. Uncomment the imports above and the code below.
    // -------------------------------------------------------------------------

    try {
      await Firebase.initializeApp();
      
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
        messaging.onTokenRefresh.listen((newToken) {
          if (session.isAuthenticated) {
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
