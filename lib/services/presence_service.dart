import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manages user online/offline presence via heartbeat and app lifecycle.
///
/// - Updates `last_seen` every 60 seconds while the app is in the foreground.
/// - Sets `is_online=false` when the app is paused/detached.
/// - Sets `is_online=true` when the app is resumed.
/// - Cleans up on dispose (logout).
class PresenceService with WidgetsBindingObserver {
  final SupabaseClient _supabase;
  Timer? _heartbeatTimer;
  String? _userId;
  bool _isActive = false;

  /// Staleness threshold: users with last_seen older than this are considered offline.
  static const Duration staleThreshold = Duration(minutes: 5);

  /// Heartbeat interval.
  static const Duration heartbeatInterval = Duration(seconds: 60);

  PresenceService(this._supabase);

  /// Start presence tracking for the given user.
  void start(String userId) {
    _userId = userId;
    _isActive = true;
    WidgetsBinding.instance.addObserver(this);
    _setOnline();
    _startHeartbeat();
  }

  /// Stop presence tracking (e.g., on logout).
  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    if (_userId != null) {
      _setOffline();
    }
    _isActive = false;
    _userId = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (_isActive && _userId != null) {
        _updateLastSeen();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_userId == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _isActive = true;
        _setOnline();
        _startHeartbeat();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _isActive = false;
        _heartbeatTimer?.cancel();
        _setOffline();
        break;
      case AppLifecycleState.inactive:
        // Brief transition state — don't change presence
        break;
    }
  }

  Future<void> _setOnline() async {
    try {
      await _supabase
          .from('profiles')
          .update({
            'is_online': true,
            'last_seen': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _userId!);
    } catch (_) {
      // Ignore errors silently — presence is best-effort
    }
  }

  Future<void> _setOffline() async {
    try {
      await _supabase
          .from('profiles')
          .update({
            'is_online': false,
            'last_seen': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _userId!);
    } catch (_) {
      // Ignore errors silently — presence is best-effort
    }
  }

  Future<void> _updateLastSeen() async {
    try {
      await _supabase
          .from('profiles')
          .update({'last_seen': DateTime.now().toUtc().toIso8601String()})
          .eq('id', _userId!);
    } catch (_) {
      // Ignore errors silently — presence is best-effort
    }
  }

  /// Check if a user should be considered online based on their `is_online`
  /// flag AND `last_seen` timestamp.
  static bool isEffectivelyOnline({
    required bool isOnline,
    DateTime? lastSeen,
  }) {
    if (!isOnline) return false;
    if (lastSeen == null) return false;
    final now = DateTime.now().toUtc();
    final lastSeenUtc = lastSeen.toUtc();
    return now.difference(lastSeenUtc) < staleThreshold;
  }

  void dispose() {
    stop();
  }
}
