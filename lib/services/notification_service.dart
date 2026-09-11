import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification service for incoming and active call alerts.
///
/// Supported scenarios:
/// - App in FOREGROUND: Shows incoming call screen directly + Active Call Banner.
/// - App in BACKGROUND (alive): Shows a heads-up notification with call type/caller,
///   and an ongoing notification for active calls to recover the call UI.
class NotificationService {
  static const String _incomingChannelId = 'incoming_calls';
  static const String _incomingChannelName = 'Incoming Calls';
  static const String _incomingChannelDesc =
      'Notifications for incoming audio and video calls';
  static const int _incomingCallNotificationId = 1001;

  static const String _activeChannelId = 'active_calls';
  static const String _activeChannelName = 'Active Calls';
  static const String _activeChannelDesc =
      'Ongoing notification for active call sessions';
  static const int _activeCallNotificationId = 2002;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  final StreamController<String> _tapController =
      StreamController<String>.broadcast();

  Stream<String> get onNotificationTap => _tapController.stream;

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

    // Create notification channels (Android 8+)
    const incomingChannel = AndroidNotificationChannel(
      _incomingChannelId,
      _incomingChannelName,
      description: _incomingChannelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    const activeChannel = AndroidNotificationChannel(
      _activeChannelId,
      _activeChannelName,
      description: _activeChannelDesc,
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidImpl?.createNotificationChannel(incomingChannel);
    await androidImpl?.createNotificationChannel(activeChannel);

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
      _incomingChannelId,
      _incomingChannelName,
      channelDescription: _incomingChannelDesc,
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
      payload: 'incoming_call',
    );
  }

  /// Show an ongoing active call notification so minimized calls remain recoverable.
  Future<void> showActiveCallNotification({
    required String contactName,
    required bool isVideo,
  }) async {
    if (!_isInitialized) await initialize();

    final callType = isVideo ? 'Video' : 'Audio';
    const androidDetails = AndroidNotificationDetails(
      _activeChannelId,
      _activeChannelName,
      channelDescription: _activeChannelDesc,
      importance: Importance.low,
      priority: Priority.low,
      category: AndroidNotificationCategory.call,
      ongoing: true,
      autoCancel: false,
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      _activeCallNotificationId,
      'Active $callType Call with $contactName',
      'Tap to return to active call controls',
      const NotificationDetails(android: androidDetails),
      payload: 'active_call',
    );
  }

  /// Cancel the incoming call notification.
  Future<void> cancelIncomingCallNotification() async {
    await _plugin.cancel(_incomingCallNotificationId);
  }

  /// Cancel the active call notification.
  Future<void> cancelActiveCallNotification() async {
    await _plugin.cancel(_activeCallNotificationId);
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload ?? 'active_call';
    if (!_tapController.isClosed) {
      _tapController.add(payload);
    }
  }

  Future<void> dispose() async {
    await cancelIncomingCallNotification();
    await cancelActiveCallNotification();
    if (!_tapController.isClosed) {
      _tapController.close();
    }
  }
}
