import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pulchowkx_app/services/api_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    try {
      // Request permissions for iOS
      // Request permissions for both iOS and Android (required for Android 13+)
      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      // Initialize local notifications for foreground alerts
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification tap
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      // Create high importance channel for Android
      if (Platform.isAndroid) {
        const channel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important campus updates.',
          importance: Importance.max,
        );

        await _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.createNotificationChannel(channel);
      }

      // Auto-subscribe to default topics
      await subscribeToTopic('events');
      await subscribeToTopic('books');

      // Sync FCM token if user is already logged in
      await syncToken();

      // Handle background messages
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');

        final notification = message.notification;
        final android = message.notification?.android;

        if (notification != null) {
          _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'high_importance_channel',
                'High Importance Notifications',
                channelDescription:
                    'This channel is used for important campus updates.',
                importance: Importance.max,
                priority: Priority.high,
                icon: android?.smallIcon,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            payload: message.data.toString(),
          );
        }
      });

      // Handle message open app
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('A new onMessageOpenedApp event was published!');
      });
    } catch (e) {
      debugPrint('Notification service initialization failed: $e');
    }
  }

  static Future<String?> getToken() async {
    final token = await _messaging.getToken();
    debugPrint('FCM Token: $token');
    return token;
  }

  static Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic $topic: $e');
    }
  }

  static Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }

  static Future<void> syncToken() async {
    try {
      final token = await getToken();
      if (token == null) return;

      final apiService = ApiService();
      final dbUserId = await apiService.getDatabaseUserId();

      // We only sync if we have a stored database user ID
      // If not logged in yet, the sync will happen during login
      if (dbUserId != null) {
        // Fetch current user details from profile or use dummy if only token update is needed
        // Assuming sync-user handles partial updates or we can just send the ID and token
        // For now, we'll rely on the login sync, but this is good for token refreshes
        _messaging.onTokenRefresh.listen((newToken) async {
          // Handle token refresh
        });
      }
    } catch (e) {
      debugPrint('Error syncing token: $e');
    }
  }

  static Future<void> subscribeToFaculty(int facultyId) async {
    await subscribeToTopic('faculty_$facultyId');
  }

  static Future<bool> hasPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }
}

// Global background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling a background message: ${message.messageId}");
}
