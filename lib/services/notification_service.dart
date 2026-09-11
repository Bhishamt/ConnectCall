import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification service for incoming call alerts.
///
/// Supported scenarios:
/// - App in FOREGROUND: Shows incoming call screen directly (no notification needed).
/// - App in BACKGROUND (alive): Shows a heads-up notification with call type/caller.
/// - App TERMINATED: NOT SUPPORTED without FCM infrastructure.
///
/// To support terminated-state calling, Firebase Cloud Messaging (FCM) + a
/// Supabase Edge Function or Database Webhook would be required to send push
/// notifications to the device. This is documented in KNOWN_LIMITATIONS.md.
class NotificationService {
  static const String _channelId = 'incoming_calls';
  static const String _channelName = 'Incoming Calls';
  static const String _channelDesc =
      'Notifications for incoming audio and video calls';
  static const int _incomingCallNotificationId = 1001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create the notification channel (Android 8+)
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);

    _isInitialized = true;
  }

  /// Request notification permission (Android 13+).
  Future<bool> requestPermission() async {
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl == null) return false;
    final granted = await androidImpl.requestNotificationsPermission();
    return granted ?? false;
  }

  /// Show an incoming call notification when the app is backgrounded.
  Future<void> showIncomingCallNotification({
    required String callerName,
    required bool isVideo,
  }) async {
    if (!_isInitialized) await initialize();

    final callType = isVideo ? 'Video' : 'Audio';
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true, // Show even on lock screen
      autoCancel: true,
      ongoing: false,
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      _incomingCallNotificationId,
      'Incoming $callType Call',
      '$callerName is calling...',
      const NotificationDetails(android: androidDetails),
    );
  }

  /// Cancel the incoming call notification (when call is answered or ended).
  Future<void> cancelIncomingCallNotification() async {
    await _plugin.cancel(_incomingCallNotificationId);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // When user taps the notification, the app comes to foreground automatically.
    // The CallNotifier's incoming call subscription will handle showing the UI.
  }

  Future<void> dispose() async {
    await cancelIncomingCallNotification();
  }
}
