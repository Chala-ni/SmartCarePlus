/// SMARTCARE+ Notification Service
///
/// Handles Firebase Cloud Messaging (FCM) for push notifications
/// Supports foreground, background, and terminated state notifications

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 Background message received: ${message.notification?.title}');
  // Background notifications are automatically shown by the system
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize notification service
  Future<void> initialize() async {
    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );
    
    debugPrint('🔔 Notification permission: ${settings.authorizationStatus}');
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      
      // Initialize local notifications for foreground
      await _initializeLocalNotifications();
      
      // Get FCM token
      _fcmToken = await _messaging.getToken();
      debugPrint('🔑 FCM Token: $_fcmToken');
      
      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('🔄 FCM Token refreshed: $newToken');
      });
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle message tap when app was in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
      
      // Check if app was opened from a terminated state notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageTap(initialMessage);
      }
    }
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap from local notification
        if (details.payload != null) {
          final data = json.decode(details.payload!);
          _navigateToAlert(data);
        }
      },
    );
    
    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'smartcare_alerts',
      'SmartCare+ Alerts',
      description: 'Emergency alerts and notifications from SmartCare+',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Handle foreground messages - show local notification
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📬 Foreground message: ${message.notification?.title}');
    
    final notification = message.notification;
    if (notification != null) {
      _showLocalNotification(
        title: notification.title ?? 'SmartCare+ Alert',
        body: notification.body ?? '',
        payload: json.encode(message.data),
      );
    }
  }

  /// Handle notification tap
  void _handleMessageTap(RemoteMessage message) {
    debugPrint('👆 Notification tapped: ${message.notification?.title}');
    _navigateToAlert(message.data);
  }

  /// Navigate to alert screen based on notification data
  void _navigateToAlert(Map<String, dynamic> data) {
    // This would use a navigator key or context to navigate
    // For now, just log the intent
    final alertId = data['alert_id'];
    final alertType = data['alert_type'];
    debugPrint('🔀 Navigate to alert: $alertId ($alertType)');
    // TODO: Implement navigation using GlobalKey<NavigatorState>
  }

  /// Show local notification (for foreground)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'smartcare_alerts',
      'SmartCare+ Alerts',
      channelDescription: 'Emergency alerts and notifications from SmartCare+',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF00FFFF), // Neon cyan
      category: AndroidNotificationCategory.alarm,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Save FCM token to Firestore for a user
  Future<void> saveTokenToFirestore(String userId) async {
    if (_fcmToken == null || userId.isEmpty) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'fcm_token': _fcmToken});
      debugPrint('✅ FCM token saved for user: $userId');
    } catch (e) {
      debugPrint('❌ Failed to save FCM token: $e');
    }
  }

  /// Subscribe to topic (e.g., "guardians", "caregivers")
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('📡 Subscribed to topic: $topic');
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('📡 Unsubscribed from topic: $topic');
  }
}
