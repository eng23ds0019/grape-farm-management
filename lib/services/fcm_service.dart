import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("FcmService: Handling a background message: ${message.messageId}");
  // Display a local system notification for background/terminated FCM messages
  if (message.notification != null) {
    await FcmService.showLocalNotification(
      title: message.notification!.title ?? "⚠️ Disease Alert",
      body: message.notification!.body ?? "High Disease Risk detected.",
    );
  }
}

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize FCM token registration, listeners, permissions, and channels
  static Future<void> initialize(String userId) async {
    if (_initialized) return;
    try {
      debugPrint("FcmService: Initializing FCM services for user: $userId...");

      // 1. Request notifications permissions (Android 13+ runtime permissions)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint("FcmService: User permission status: ${settings.authorizationStatus}");

      // 2. Initialize local notifications for foreground alerts
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("FcmService: Local notification tapped: ${response.payload}");
        },
      );

      // Create high-importance Android Notification Channels
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        try {
          await androidImplementation.requestNotificationsPermission();
        } catch (e_perm) {
          debugPrint("FcmService: Error requesting local notification permissions: $e_perm");
        }
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'disease_alerts_channel',
            'Disease Alerts',
            description: 'Alerts and warnings for powdery mildew and downy mildew risks',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'weather_alerts_channel',
            'Weather Alerts',
            description: 'Warnings about upcoming rainfall and timing of sprays',
            importance: Importance.max,
            playSound: true,
          ),
        );
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            'reminders_channel',
            'Spray Reminders',
            description: 'Reminders about overdue spraying dates',
            importance: Importance.high,
            playSound: true,
          ),
        );
      }

      // 3. Register and Sync FCM Token
      await syncTokenToFirestore(userId);

      // 4. Token Refresh Listener
      _messaging.onTokenRefresh.listen((newToken) async {
        debugPrint("FcmService: Token refreshed. Syncing to Firestore...");
        await _saveTokenToDb(userId, newToken);
      });

      // 5. Setup Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint("FcmService: Received foreground message: ${message.messageId}");
        if (message.notification != null) {
          showLocalNotification(
            title: message.notification!.title ?? "⚠️ Disease Alert",
            body: message.notification!.body ?? "High Disease Risk detected.",
            payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
          );
        }
      });

      // 6. Setup Background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      _initialized = true;
      debugPrint("FcmService: Successfully initialized and listening.");
    } catch (e) {
      debugPrint("FcmService: Initialization error: $e");
    }
  }

  /// Retrieve and sync token to user collection: users/{userId}/fcmTokens/{token}
  static Future<void> syncTokenToFirestore(String userId) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToDb(userId, token);
      } else {
        debugPrint("FcmService: Could not retrieve FCM token.");
      }
    } catch (e) {
      debugPrint("FcmService: Error syncing token: $e");
    }
  }

  static Future<void> _saveTokenToDb(String userId, String token) async {
    try {
      final db = FirebaseFirestore.instance;
      await db
          .collection('users')
          .doc(userId)
          .collection('fcmTokens')
          .doc(token)
          .set({
        'token': token,
        'createdAt': FieldValue.serverTimestamp(),
        'platform': 'android',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint("FcmService: Synced token successfully: ${token.substring(0, min(token.length, 12))}...");
    } catch (e) {
      debugPrint("FcmService: Error saving token to database: $e");
    }
  }

  /// Shows a system tray notification locally (handles background & foreground FCM pushes)
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      // Determine the channel depending on the warning title
      String channelId = 'disease_alerts_channel';
      String channelName = 'Disease Alerts';
      if (title.contains('Rain') || title.contains('Weather')) {
        channelId = 'weather_alerts_channel';
        channelName = 'Weather Alerts';
      } else if (title.contains('Reminder') || title.contains('overdue')) {
        channelId = 'reminders_channel';
        channelName = 'Spray Reminders';
      }

      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
        icon: '@mipmap/ic_launcher',
      );

      final platformDetails = NotificationDetails(android: androidDetails);
      final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _localNotificationsPlugin.show(
        notificationId,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint("FcmService: Error showing local notification: $e");
    }
  }

  static int min(int a, int b) => a < b ? a : b;
}
