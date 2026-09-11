import 'dart:async';

import 'package:flutter/services.dart';

/// Manages call ringing audio feedback for outgoing and incoming calls.
///
/// Features:
/// - Outgoing call: plays periodic outgoing ringing chimes.
/// - Incoming call: plays periodic incoming call alert chimes.
/// - Stops cleanly on call connect, reject, end, or timeout.
/// - Prevents duplicate player loops and memory leaks.
class RingtoneService {
  Timer? _ringtoneTimer;
  bool _isPlaying = false;
  String? _currentType;

  /// Play outgoing call ringing feedback chime.
  void startOutgoingRingtone() {
    stop();
    _currentType = 'outgoing';
    _isPlaying = true;
    _playTone();
    _ringtoneTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_isPlaying && _currentType == 'outgoing') {
        _playTone();
      }
    });
  }

  /// Play incoming call ringing feedback chime.
  void startIncomingRingtone() {
    stop();
    _currentType = 'incoming';
    _isPlaying = true;
    _playAlertTone();
    _ringtoneTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_isPlaying && _currentType == 'incoming') {
        _playAlertTone();
      }
    });
  }

  void _playTone() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  void _playAlertTone() {
    try {
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  /// Stop all active ringtone loops cleanly.
  void stop() {
    _isPlaying = false;
    _currentType = null;
    _ringtoneTimer?.cancel();
    _ringtoneTimer = null;
  }

  void dispose() {
    stop();
  }
}
