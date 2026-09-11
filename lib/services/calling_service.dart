import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../models/call_model.dart';

abstract class CallingService {
  RTCVideoRenderer get localRenderer;
  RTCVideoRenderer get remoteRenderer;

  /// Stream of WebRTC-level call status updates.
  /// Emits: connecting, connected, failed, disconnected, ended, rejected.
  Stream<CallStatus> get statusStream;

  Future<void> initialize();
  Future<void> startCall({
    required CallModel call,
    required String currentUserId,
  });
  Future<void> acceptCall({
    required CallModel call,
    required String currentUserId,
  });
  Future<void> rejectCall({required CallModel call});
  Future<void> endCall();

  Future<void> toggleMicrophone(bool isMuted);
  Future<void> toggleCamera(bool isCameraOff);
  Future<void> switchCamera();
  Future<void> toggleSpeaker(bool isSpeakerOn);

  void dispose();
}
