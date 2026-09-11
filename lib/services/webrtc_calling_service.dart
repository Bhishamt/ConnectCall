import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'calling_service.dart';
import '../models/call_model.dart';
import '../core/errors/app_exception.dart';

/// Complete WebRTC calling service with fixed signaling flow.
///
/// ## Fixed Signaling Flow (Caller → Receiver):
///
/// CALLER:
///   1. Subscribe to channel
///   2. Get local media
///   3. Create PeerConnection + add tracks
///   4. Set up ICE + onTrack handlers
///   5. Wait for receiver `ready` signal (max 30s)
///   6. Create + send Offer
///
/// RECEIVER:
///   1. Subscribe to channel
///   2. Get local media
///   3. Create PeerConnection + add tracks
///   4. Set up ICE + onTrack handlers
///   5. Send `ready` signal → triggers caller to send Offer
///   6. Receive Offer → setRemoteDescription → createAnswer → send Answer
///
/// This ensures both sides are subscribed before SDP exchange begins.
class WebRTCCallingService implements CallingService {
  final SupabaseClient _supabase;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  RealtimeChannel? _signalingChannel;
  String? _currentUserId;

  bool _isInitialized = false;
  bool _isEnded = false;

  final List<RTCIceCandidate> _pendingIceCandidates = [];

  final StreamController<CallStatus> _statusController =
      StreamController<CallStatus>.broadcast();

  @override
  Stream<CallStatus> get statusStream => _statusController.stream;

  WebRTCCallingService(this._supabase);

  @override
  RTCVideoRenderer get localRenderer => _localRenderer;

  @override
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _isInitialized = true;
  }

  Map<String, dynamic> get _rtcConfig => {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun.relay.metered.ca:80'},
    ],
    'sdpSemantics': 'unified-plan',
    'iceCandidatePoolSize': 10,
  };

  Map<String, dynamic> _mediaConstraints(bool isVideo) => {
    'audio': {
      'mandatory': {
        'googNoiseSuppression': true,
        'googEchoCancellation': true,
        'googAutoGainControl': true,
      },
      'optional': [],
    },
    'video': isVideo
        ? {
            'mandatory': {
              'minWidth': '640',
              'minHeight': '480',
              'minFrameRate': '24',
            },
            'facingMode': 'user',
            'optional': [],
          }
        : false,
  };

  // ──────────────────────────────────────────────────────────────────────────
  // CALLER: startCall
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Future<void> startCall({
    required CallModel call,
    required String currentUserId,
  }) async {
    await initialize();
    _currentUserId = currentUserId;
    _isEnded = false;
    _pendingIceCandidates.clear();

    _emitStatus(CallStatus.calling);

    try {
      // 1. Get local media stream
      final isVideo = call.callType == CallType.video;
      _localStream = await navigator.mediaDevices.getUserMedia(
        _mediaConstraints(isVideo),
      );
      _localRenderer.srcObject = _localStream;

      // 2. Create peer connection
      await _createPeerConnection(currentUserId);

      // 3. Subscribe to signaling channel (must happen before sending anything)
      final channelReady = Completer<void>();
      _signalingChannel = _supabase.channel(
        'call_signaling_${call.id}',
        opts: const RealtimeChannelConfig(ack: true),
      );
      _setupSignalingHandlers(call: call, isCaller: true);

      _signalingChannel!.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          if (!channelReady.isCompleted) channelReady.complete();
        }
      });

      // Wait for channel to be ready (max 8 seconds)
      await channelReady.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw AppException(
          'Signaling channel timeout',
          'signaling_timeout',
        ),
      );

      // 4. Wait for receiver `ready` signal — handled in _setupSignalingHandlers
      // The offer is sent from _onReceiverReady() callback.
      // Set a timeout for the receiver to become ready (30s handled in call_provider)
    } catch (e) {
      await _cleanup();
      throw AppException.fromException(e);
    }
  }

  // Called when receiver sends `ready` event — CALLER creates + sends offer
  Future<void> _onReceiverReady() async {
    if (_isEnded || _peerConnection == null) return;
    try {
      _emitStatus(CallStatus.connecting);

      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _peerConnection!.setLocalDescription(offer);

      _signalingChannel?.sendBroadcastMessage(
        event: 'offer',
        payload: {'sender_id': _currentUserId, 'sdp': offer.toMap()},
      );
    } catch (e) {
      _emitStatus(CallStatus.failed);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // RECEIVER: acceptCall
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Future<void> acceptCall({
    required CallModel call,
    required String currentUserId,
  }) async {
    await initialize();
    _currentUserId = currentUserId;
    _isEnded = false;
    _pendingIceCandidates.clear();

    _emitStatus(CallStatus.connecting);

    try {
      // 1. Get local media stream
      final isVideo = call.callType == CallType.video;
      _localStream = await navigator.mediaDevices.getUserMedia(
        _mediaConstraints(isVideo),
      );
      _localRenderer.srcObject = _localStream;

      // 2. Create peer connection
      await _createPeerConnection(currentUserId);

      // 3. Subscribe to signaling channel
      final channelReady = Completer<void>();
      _signalingChannel = _supabase.channel(
        'call_signaling_${call.id}',
        opts: const RealtimeChannelConfig(ack: true),
      );
      _setupSignalingHandlers(call: call, isCaller: false);

      _signalingChannel!.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          if (!channelReady.isCompleted) channelReady.complete();
        }
      });

      // Wait for channel to be ready before sending `ready`
      await channelReady.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw AppException(
          'Signaling channel timeout',
          'signaling_timeout',
        ),
      );

      // 4. Signal to caller that we're ready to receive the offer
      _signalingChannel!.sendBroadcastMessage(
        event: 'ready',
        payload: {'sender_id': currentUserId},
      );
    } catch (e) {
      await _cleanup();
      throw AppException.fromException(e);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Common: Create RTCPeerConnection
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _createPeerConnection(String currentUserId) async {
    _peerConnection = await createPeerConnection(_rtcConfig);

    // Add local tracks
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    // Handle remote tracks
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        _remoteRenderer.srcObject = _remoteStream;
      }
    };

    // ICE candidate handler
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        _signalingChannel?.sendBroadcastMessage(
          event: 'ice-candidate',
          payload: {'sender_id': currentUserId, 'candidate': candidate.toMap()},
        );
      }
    };

    // Connection state monitoring
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _emitStatus(CallStatus.connected);
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          if (!_isEnded) _emitStatus(CallStatus.failed);
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          if (!_isEnded) _emitStatus(CallStatus.disconnected);
          break;
        default:
          break;
      }
    };

    // ICE connection state
    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      // Log only — connection state above is authoritative
    };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Signaling handlers (shared by caller and receiver)
  // ──────────────────────────────────────────────────────────────────────────
  void _setupSignalingHandlers({
    required CallModel call,
    required bool isCaller,
  }) {
    _signalingChannel!
        .onBroadcast(
          event: 'ready',
          callback: (payload) async {
            // Only the CALLER handles `ready` — receiver sent this
            if (isCaller &&
                payload['sender_id'] != _currentUserId &&
                !_isEnded) {
              await _onReceiverReady();
            }
          },
        )
        .onBroadcast(
          event: 'offer',
          callback: (payload) async {
            // Only the RECEIVER handles `offer`
            if (!isCaller &&
                payload['sender_id'] != _currentUserId &&
                _peerConnection != null &&
                !_isEnded) {
              try {
                final sdpMap = payload['sdp'] as Map<String, dynamic>;
                final offer = RTCSessionDescription(
                  sdpMap['sdp'] as String?,
                  sdpMap['type'] as String?,
                );
                await _peerConnection!.setRemoteDescription(offer);
                await _drainPendingIceCandidates();

                final answer = await _peerConnection!.createAnswer({
                  'offerToReceiveAudio': true,
                  'offerToReceiveVideo': true,
                });
                await _peerConnection!.setLocalDescription(answer);

                _signalingChannel!.sendBroadcastMessage(
                  event: 'answer',
                  payload: {'sender_id': _currentUserId, 'sdp': answer.toMap()},
                );
              } catch (_) {
                _emitStatus(CallStatus.failed);
              }
            }
          },
        )
        .onBroadcast(
          event: 'answer',
          callback: (payload) async {
            // Only the CALLER handles `answer`
            if (isCaller &&
                payload['sender_id'] != _currentUserId &&
                _peerConnection != null &&
                !_isEnded) {
              try {
                final sdpMap = payload['sdp'] as Map<String, dynamic>;
                final answer = RTCSessionDescription(
                  sdpMap['sdp'] as String?,
                  sdpMap['type'] as String?,
                );
                await _peerConnection!.setRemoteDescription(answer);
                await _drainPendingIceCandidates();
                // Note: CallStatus.connected comes from onConnectionState
              } catch (_) {
                _emitStatus(CallStatus.failed);
              }
            }
          },
        )
        .onBroadcast(
          event: 'ice-candidate',
          callback: (payload) async {
            if (payload['sender_id'] != _currentUserId &&
                _peerConnection != null &&
                !_isEnded) {
              try {
                final candMap = payload['candidate'] as Map<String, dynamic>;
                final candidate = RTCIceCandidate(
                  candMap['candidate'] as String?,
                  candMap['sdpMid'] as String?,
                  candMap['sdpMLineIndex'] as int?,
                );
                final remoteDesc = await _peerConnection!
                    .getRemoteDescription();
                if (remoteDesc != null) {
                  await _peerConnection!.addCandidate(candidate);
                } else {
                  _pendingIceCandidates.add(candidate);
                }
              } catch (_) {
                // Ignore individual bad candidates
              }
            }
          },
        )
        .onBroadcast(
          event: 'reject',
          callback: (payload) {
            if (!_isEnded) _emitStatus(CallStatus.rejected);
          },
        )
        .onBroadcast(
          event: 'end',
          callback: (payload) {
            if (!_isEnded) _emitStatus(CallStatus.ended);
          },
        );
  }

  Future<void> _drainPendingIceCandidates() async {
    if (_peerConnection == null) return;
    final candidates = List<RTCIceCandidate>.from(_pendingIceCandidates);
    _pendingIceCandidates.clear();
    for (final candidate in candidates) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (_) {
        // Ignore individual candidate errors
      }
    }
  }

  void _emitStatus(CallStatus status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Control methods
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Future<void> rejectCall({required CallModel call}) async {
    // Subscribe briefly to send reject, then cleanup
    final ch = _supabase.channel('call_signaling_${call.id}');
    ch.subscribe((status, [_]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        ch.sendBroadcastMessage(
          event: 'reject',
          payload: {'sender_id': _currentUserId},
        );
        Future.delayed(const Duration(milliseconds: 300), () {
          ch.unsubscribe();
        });
      }
    });
    await _cleanup();
  }

  @override
  Future<void> endCall() async {
    if (_isEnded) return;
    _isEnded = true;
    try {
      _signalingChannel?.sendBroadcastMessage(
        event: 'end',
        payload: {'sender_id': _currentUserId},
      );
    } catch (_) {}
    await _cleanup();
    _emitStatus(CallStatus.ended);
  }

  Future<void> _cleanup() async {
    _isEnded = true;
    _pendingIceCandidates.clear();

    try {
      await _signalingChannel?.unsubscribe();
    } catch (_) {}
    _signalingChannel = null;

    try {
      _localStream?.getTracks().forEach((track) => track.stop());
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;

    try {
      _remoteStream?.getTracks().forEach((track) => track.stop());
      await _remoteStream?.dispose();
    } catch (_) {}
    _remoteStream = null;

    try {
      await _peerConnection?.close();
    } catch (_) {}
    _peerConnection = null;

    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Media controls
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Future<void> toggleMicrophone(bool isMuted) async {
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !isMuted;
    });
  }

  @override
  Future<void> toggleCamera(bool isCameraOff) async {
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !isCameraOff;
    });
  }

  @override
  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty) {
      await Helper.switchCamera(tracks.first);
    }
  }

  @override
  Future<void> toggleSpeaker(bool isSpeakerOn) async {
    await Helper.setSpeakerphoneOn(isSpeakerOn);
  }

  @override
  void dispose() {
    _cleanup();
    if (!_statusController.isClosed) {
      _statusController.close();
    }
    if (_isInitialized) {
      _localRenderer.dispose();
      _remoteRenderer.dispose();
      _isInitialized = false;
    }
  }
}
