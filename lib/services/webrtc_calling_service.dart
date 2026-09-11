import 'dart:async';
import 'dart:developer' as developer;

import 'package:audio_session/audio_session.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'calling_service.dart';
import '../models/call_model.dart';
import '../core/errors/app_exception.dart';

/// WebRTC calling service with symmetric video rendering & audio session routing.
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

  void _log(String message) {
    developer.log('[WEBRTC] $message');
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _isInitialized = true;
    _log('Renderers initialized');
  }

  /// Configure AudioSession for VoIP voice communication.
  Future<void> _configureAudioSession(bool isVideo) async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.allowBluetooth |
              AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: isVideo
              ? AVAudioSessionMode.videoChat
              : AVAudioSessionMode.voiceChat,
          androidAudioAttributes: const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
          androidWillPauseWhenDucked: true,
        ),
      );
      await session.setActive(true);
      _log(
        'AudioSession configured for ${isVideo ? "videoChat" : "voiceChat"}',
      );
    } catch (e) {
      _log('AudioSession config error: $e');
    }
  }

  Map<String, dynamic> get _rtcConfig => {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
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
        'googHighpassFilter': true,
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
      final isVideo = call.callType == CallType.video;
      await _configureAudioSession(isVideo);

      // 1. Get local media stream
      _localStream = await navigator.mediaDevices.getUserMedia(
        _mediaConstraints(isVideo),
      );
      _localRenderer.srcObject = _localStream;
      _log(
        'Local stream captured (tracks: ${_localStream?.getTracks().length})',
      );

      // 2. Create peer connection
      await _createPeerConnection(currentUserId);

      // 3. Subscribe to signaling channel
      final channelReady = Completer<void>();
      _signalingChannel = _supabase.channel(
        'call_signaling_${call.id}',
        opts: const RealtimeChannelConfig(ack: true),
      );
      _setupSignalingHandlers(call: call, isCaller: true);

      _signalingChannel!.subscribe((status, [error]) {
        _log('Signaling subscription status: $status');
        if (status == RealtimeSubscribeStatus.subscribed) {
          if (!channelReady.isCompleted) channelReady.complete();
        }
      });

      await channelReady.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw AppException(
          'Signaling channel timeout',
          'signaling_timeout',
        ),
      );
    } catch (e) {
      _log('startCall error: $e');
      await _cleanup();
      throw AppException.fromException(e);
    }
  }

  // CALLER creates + sends offer when receiver sends `ready`
  Future<void> _onReceiverReady() async {
    if (_isEnded || _peerConnection == null) return;
    try {
      _log('Receiver is ready. Creating SDP offer...');
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
      _log('SDP offer sent');
    } catch (e) {
      _log('createOffer error: $e');
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
      final isVideo = call.callType == CallType.video;
      await _configureAudioSession(isVideo);

      // 1. Get local media stream
      _localStream = await navigator.mediaDevices.getUserMedia(
        _mediaConstraints(isVideo),
      );
      _localRenderer.srcObject = _localStream;
      _log('Receiver local stream captured');

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
        _log('Receiver signaling status: $status');
        if (status == RealtimeSubscribeStatus.subscribed) {
          if (!channelReady.isCompleted) channelReady.complete();
        }
      });

      await channelReady.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw AppException(
          'Signaling channel timeout',
          'signaling_timeout',
        ),
      );

      // 4. Send `ready` signal to caller
      _signalingChannel!.sendBroadcastMessage(
        event: 'ready',
        payload: {'sender_id': currentUserId},
      );
      _log('Sent `ready` signal to caller');
    } catch (e) {
      _log('acceptCall error: $e');
      await _cleanup();
      throw AppException.fromException(e);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // PeerConnection creation & Symmetrical Remote Track Assignment
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _createPeerConnection(String currentUserId) async {
    _peerConnection = await createPeerConnection(_rtcConfig);
    _log('RTCPeerConnection created');

    // Add local tracks
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    // Symmetrical Track Handler for Remote Streams
    _peerConnection!.onTrack = (RTCTrackEvent event) async {
      _log(
        'onTrack event: kind=${event.track.kind}, streams=${event.streams.length}',
      );

      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
      } else {
        _remoteStream ??= await createLocalMediaStream('remote_stream');
        _remoteStream!.addTrack(event.track);
      }

      // Always re-bind remoteRenderer when tracks arrive
      _remoteRenderer.srcObject = _remoteStream;
      _log(
        'Remote renderer srcObject assigned (videoTracks: ${_remoteStream?.getVideoTracks().length})',
      );
    };

    _peerConnection!.onAddStream = (MediaStream stream) {
      _log(
        'onAddStream event (videoTracks: ${stream.getVideoTracks().length})',
      );
      _remoteStream = stream;
      _remoteRenderer.srcObject = _remoteStream;
    };

    // ICE Candidate handler
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
        _signalingChannel?.sendBroadcastMessage(
          event: 'ice-candidate',
          payload: {'sender_id': currentUserId, 'candidate': candidate.toMap()},
        );
      }
    };

    // Connection State
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      _log('PeerConnection state changed: $state');
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

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      _log('ICE Connection state: $state');
    };
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Signaling Message Handlers
  // ──────────────────────────────────────────────────────────────────────────
  void _setupSignalingHandlers({
    required CallModel call,
    required bool isCaller,
  }) {
    _signalingChannel!
        .onBroadcast(
          event: 'ready',
          callback: (payload) async {
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
            if (!isCaller &&
                payload['sender_id'] != _currentUserId &&
                _peerConnection != null &&
                !_isEnded) {
              try {
                _log(
                  'Receiver received offer SDP. Setting remote description...',
                );
                final sdpMap = payload['sdp'] as Map<String, dynamic>;
                final offer = RTCSessionDescription(
                  sdpMap['sdp'] as String?,
                  sdpMap['type'] as String?,
                );
                await _peerConnection!.setRemoteDescription(offer);
                await _drainPendingIceCandidates();

                _log('Creating answer SDP...');
                final answer = await _peerConnection!.createAnswer({
                  'offerToReceiveAudio': true,
                  'offerToReceiveVideo': true,
                });
                await _peerConnection!.setLocalDescription(answer);

                _signalingChannel!.sendBroadcastMessage(
                  event: 'answer',
                  payload: {'sender_id': _currentUserId, 'sdp': answer.toMap()},
                );
                _log('Answer SDP sent');
              } catch (e) {
                _log('Offer handling error: $e');
                _emitStatus(CallStatus.failed);
              }
            }
          },
        )
        .onBroadcast(
          event: 'answer',
          callback: (payload) async {
            if (isCaller &&
                payload['sender_id'] != _currentUserId &&
                _peerConnection != null &&
                !_isEnded) {
              try {
                _log(
                  'Caller received answer SDP. Setting remote description...',
                );
                final sdpMap = payload['sdp'] as Map<String, dynamic>;
                final answer = RTCSessionDescription(
                  sdpMap['sdp'] as String?,
                  sdpMap['type'] as String?,
                );
                await _peerConnection!.setRemoteDescription(answer);
                await _drainPendingIceCandidates();
              } catch (e) {
                _log('Answer handling error: $e');
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
              } catch (_) {}
            }
          },
        )
        .onBroadcast(
          event: 'reject',
          callback: (payload) {
            _log('Received `reject` event');
            if (!_isEnded) _emitStatus(CallStatus.rejected);
          },
        )
        .onBroadcast(
          event: 'end',
          callback: (payload) {
            _log('Received `end` event');
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
      } catch (_) {}
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
    _log('Rejecting call ${call.id}');
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
    _log('Ending call session');
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
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}

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
    _log('Cleanup completed');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Media controls
  // ──────────────────────────────────────────────────────────────────────────
  @override
  Future<void> toggleMicrophone(bool isMuted) async {
    _log('toggleMicrophone: isMuted=$isMuted');
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !isMuted;
    });
  }

  @override
  Future<void> toggleCamera(bool isCameraOff) async {
    _log('toggleCamera: isCameraOff=$isCameraOff');
    _localStream?.getVideoTracks().forEach((track) {
      track.enabled = !isCameraOff;
    });
  }

  @override
  Future<void> switchCamera() async {
    _log('switchCamera requested');
    final tracks = _localStream?.getVideoTracks();
    if (tracks != null && tracks.isNotEmpty) {
      await Helper.switchCamera(tracks.first);
    }
  }

  @override
  Future<void> toggleSpeaker(bool isSpeakerOn) async {
    _log('toggleSpeaker: isSpeakerOn=$isSpeakerOn');
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
