library notification_service;

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

typedef NotificationClickCallback = void Function(Map<String, dynamic> data);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  NotificationClickCallback? _onNotificationClick;

  Future<void> initialize({
    required NotificationClickCallback onNotificationClick,
  }) async {
    _onNotificationClick = onNotificationClick;

    await Firebase.initializeApp();

    if (Platform.isIOS) {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      print('iOS permission: ${settings.authorizationStatus}');

      final apnsToken = await _messaging.getAPNSToken();
      if (apnsToken == null) {
        print('APNS token not yet available.');
        return;
      }
    }

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Local notification clicked');
        _onNotificationClick?.call({'source': 'local', 'payload': response.payload ?? ''});
      },
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
      const AndroidNotificationChannel(
        'default_channel',
        'Default',
        importance: Importance.high,
      ),
    );

     _messaging.onTokenRefresh.listen((newToken) {
      print('Token refreshed: $newToken');
    });

    await _safeGetToken();

     FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('👉 FCM Notification clicked');
      _onNotificationClick?.call(message.data);
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<String?> _safeGetToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        print('FCM Token: $token');
        return token;
      } else {
        print('FCM Token is not yet available.');
      }
    } catch (e) {
      print('Error getting FCM Token: $e');
    }
    return null;
  }

  void _onForegroundMessage(RemoteMessage message) async {
    print('Foreground Notification: ${message.notification?.title}');
    print('Data: ${message.data}');

    RemoteNotification? notification = message.notification;

    if (notification != null) {
      const androidDetails = AndroidNotificationDetails(
        'default_channel',
        'Default',
        importance: Importance.max,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        notificationDetails,
        payload: message.data.toString(),
      );
    }
  }

  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    await Firebase.initializeApp();
    print('🌙 Background Notification: ${message.messageId}');
  }
}