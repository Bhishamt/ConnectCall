import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../services/calling_service.dart';
import '../../services/webrtc_calling_service.dart';
import '../../services/permission_service.dart';
import '../../services/notification_service.dart';
import '../../repositories/call_repository.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../auth/auth_provider.dart';
import '../../core/errors/app_exception.dart';

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepository(ref.watch(supabaseClientProvider));
});

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(() => service.dispose());
  return service;
});

final callingServiceProvider = Provider<CallingService>((ref) {
  final service = WebRTCCallingService(ref.watch(supabaseClientProvider));
  ref.onDispose(() => service.dispose());
  return service;
});

class CallState {
  final CallStatus status;
  final CallModel? activeCall;
  final bool isMuted;
  final bool isCameraOff;
  final bool isSpeakerOn;
  final int durationSeconds;
  final String? errorMessage;

  CallState({
    this.status = CallStatus.idle,
    this.activeCall,
    this.isMuted = false,
    this.isCameraOff = false,
    this.isSpeakerOn = false,
    this.durationSeconds = 0,
    this.errorMessage,
  });

  CallState copyWith({
    CallStatus? status,
    CallModel? activeCall,
    bool? isMuted,
    bool? isCameraOff,
    bool? isSpeakerOn,
    int? durationSeconds,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CallState(
      status: status ?? this.status,
      activeCall: activeCall ?? this.activeCall,
      isMuted: isMuted ?? this.isMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class CallNotifier extends StateNotifier<CallState> {
  final CallingService _callingService;
  final CallRepository _callRepo;
  final PermissionService _permissionService;
  final NotificationService _notificationService;
  final String? _currentUserId;

  Timer? _durationTimer;
  Timer? _ringTimeoutTimer;
  Timer? _connectingTimeoutTimer;
  StreamSubscription<List<CallModel>>? _incomingSubscription;
  StreamSubscription<CallStatus>? _rtcStatusSubscription;

  /// Time when the call was answered — used for accurate duration computation
  DateTime? _answeredAt;

  CallNotifier(
    this._callingService,
    this._callRepo,
    this._permissionService,
    this._notificationService,
    this._currentUserId,
  ) : super(CallState()) {
    _listenToIncomingCalls();
    _listenToRtcStatus();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Incoming call detection via Supabase Realtime
  // ──────────────────────────────────────────────────────────────────────────
  void _listenToIncomingCalls() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;
    _incomingSubscription = _callRepo.streamIncomingCalls(currentUserId).listen(
      (calls) {
        if (calls.isNotEmpty && state.status == CallStatus.idle) {
          final incomingCall = calls.first;
          state = state.copyWith(
            status: CallStatus.ringing,
            activeCall: incomingCall,
          );
          _notificationService.showIncomingCallNotification(
            callerName: incomingCall.callerName ?? 'Someone',
            isVideo: incomingCall.callType == CallType.video,
          );
          _startRingTimeout();
        }
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // WebRTC status stream listener
  // ──────────────────────────────────────────────────────────────────────────
  void _listenToRtcStatus() {
    _rtcStatusSubscription = _callingService.statusStream.listen((status) {
      switch (status) {
        case CallStatus.connecting:
          if (state.status != CallStatus.idle &&
              state.status != CallStatus.ended) {
            _notificationService.cancelIncomingCallNotification();
            state = state.copyWith(status: CallStatus.connecting);
          }
          break;

        case CallStatus.connected:
          if (state.status != CallStatus.idle &&
              state.status != CallStatus.ended) {
            _connectingTimeoutTimer?.cancel();
            _notificationService.cancelIncomingCallNotification();
            _answeredAt = DateTime.now();
            state = state.copyWith(status: CallStatus.connected);
            _startDurationTimer();
          }
          break;

        case CallStatus.failed:
          _handleCallFailed();
          break;

        case CallStatus.disconnected:
          _handleCallDisconnected();
          break;

        case CallStatus.rejected:
          if (state.status != CallStatus.idle) {
            _cancelAllTimers();
            _notificationService.cancelIncomingCallNotification();
            _updateCallRecord(
              CallStatus.rejected,
              endedAt: DateTime.now(),
              durationSeconds: 0,
            );
            state = CallState(status: CallStatus.rejected);
            _scheduleResetToIdle();
          }
          break;

        case CallStatus.ended:
          if (state.status != CallStatus.idle &&
              state.status != CallStatus.ended) {
            _handleCallEnded();
          }
          break;

        default:
          break;
      }
    });
  }

  void _handleCallFailed() {
    _cancelAllTimers();
    _notificationService.cancelIncomingCallNotification();
    final active = state.activeCall;
    if (active != null) {
      _callRepo.updateCallStatus(
        callId: active.id,
        status: CallStatus.failed,
        endedAt: DateTime.now(),
        durationSeconds: 0,
      );
    }
    state = CallState(
      status: CallStatus.failed,
      errorMessage: 'Call failed to connect',
    );
    _scheduleResetToIdle();
  }

  void _handleCallDisconnected() {
    _cancelAllTimers();
    _notificationService.cancelIncomingCallNotification();
    final secs = state.durationSeconds;
    final active = state.activeCall;
    if (active != null) {
      _callRepo.updateCallStatus(
        callId: active.id,
        status: CallStatus.disconnected,
        endedAt: DateTime.now(),
        durationSeconds: secs,
      );
    }
    state = CallState(status: CallStatus.disconnected);
    _scheduleResetToIdle();
  }

  void _handleCallEnded() {
    _cancelAllTimers();
    _notificationService.cancelIncomingCallNotification();
    final secs = _computeDuration();
    final active = state.activeCall;
    if (active != null) {
      _callRepo.updateCallStatus(
        callId: active.id,
        status: CallStatus.ended,
        endedAt: DateTime.now(),
        durationSeconds: secs,
      );
    }
    state = CallState(status: CallStatus.ended);
    _scheduleResetToIdle();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Timeouts
  // ──────────────────────────────────────────────────────────────────────────
  void _startRingTimeout() {
    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = Timer(const Duration(seconds: 30), () async {
      if (state.status == CallStatus.calling ||
          state.status == CallStatus.ringing) {
        await _handleTimeout();
      }
    });
  }

  void _startConnectingTimeout() {
    _connectingTimeoutTimer?.cancel();
    _connectingTimeoutTimer = Timer(const Duration(seconds: 20), () async {
      if (state.status == CallStatus.connecting) {
        _handleCallFailed();
        await _callingService.endCall();
      }
    });
  }

  Future<void> _handleTimeout() async {
    _cancelAllTimers();
    _notificationService.cancelIncomingCallNotification();
    final active = state.activeCall;
    if (active != null) {
      await _callRepo.updateCallStatus(
        callId: active.id,
        status: CallStatus.missed,
        endedAt: DateTime.now(),
        durationSeconds: 0,
      );
    }
    await _callingService.endCall();
    state = CallState(status: CallStatus.missed, errorMessage: 'No answer');
    _scheduleResetToIdle();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Duration computation
  // ──────────────────────────────────────────────────────────────────────────
  int _computeDuration() {
    if (_answeredAt == null) return 0;
    final elapsed = DateTime.now().difference(_answeredAt!).inSeconds;
    return elapsed > 0 ? elapsed : 0;
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status == CallStatus.connected) {
        state = state.copyWith(durationSeconds: _computeDuration());
      }
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Call initiation
  // ──────────────────────────────────────────────────────────────────────────
  Future<bool> initiateCall({
    required UserModel recipient,
    required CallType callType,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;

    // Check Permissions
    try {
      if (callType == CallType.video) {
        await _permissionService.requestVideoPermissions();
      } else {
        await _permissionService.requestAudioPermissions();
      }
    } catch (e) {
      final appErr = AppException.fromException(e);
      state = state.copyWith(
        status: CallStatus.failed,
        errorMessage: appErr.message,
      );
      _scheduleResetToIdle();
      return false;
    }

    final callId = const Uuid().v4();
    final newCall = CallModel(
      id: callId,
      callerId: currentUserId,
      calleeId: recipient.id,
      calleeName: recipient.name,
      calleeAvatar: recipient.avatarUrl,
      callType: callType,
      direction: CallDirection.outgoing,
      status: CallStatus.calling,
      startedAt: DateTime.now(),
    );

    try {
      await _callRepo.createCallSession(newCall);
      state = state.copyWith(status: CallStatus.calling, activeCall: newCall);
      _startRingTimeout();
      _startConnectingTimeout();
      _answeredAt = null;

      await _callingService.startCall(
        call: newCall,
        currentUserId: currentUserId,
      );
      // Duration timer starts only when connected (via _listenToRtcStatus)
      return true;
    } catch (e) {
      final appErr = AppException.fromException(e);
      state = state.copyWith(
        status: CallStatus.failed,
        errorMessage: appErr.message,
      );
      await endCall();
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Accept / Reject / End
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> acceptCall() async {
    final active = state.activeCall;
    final currentUserId = _currentUserId;
    if (active == null || currentUserId == null) return;
    _ringTimeoutTimer?.cancel();
    _notificationService.cancelIncomingCallNotification();
    _answeredAt = null;

    try {
      if (active.callType == CallType.video) {
        await _permissionService.requestVideoPermissions();
      } else {
        await _permissionService.requestAudioPermissions();
      }

      state = state.copyWith(status: CallStatus.connecting);
      _startConnectingTimeout();

      await _callRepo.updateCallStatus(
        callId: active.id,
        status: CallStatus.connecting,
        answeredAt: DateTime.now(),
      );

      await _callingService.acceptCall(
        call: active,
        currentUserId: currentUserId,
      );
      // connected state + timer start happen via _listenToRtcStatus
    } catch (e) {
      final appErr = AppException.fromException(e);
      state = state.copyWith(
        status: CallStatus.failed,
        errorMessage: appErr.message,
      );
      await endCall();
    }
  }

  Future<void> rejectCall() async {
    _cancelAllTimers();
    _notificationService.cancelIncomingCallNotification();
    final active = state.activeCall;
    if (active != null) {
      await _callRepo.updateCallStatus(
        callId: active.id,
        status: CallStatus.rejected,
        endedAt: DateTime.now(),
        durationSeconds: 0,
      );
      await _callingService.rejectCall(call: active);
    }
    state = CallState(status: CallStatus.rejected);
    _scheduleResetToIdle();
  }

  Future<void> endCall() async {
    _cancelAllTimers();
    _notificationService.cancelIncomingCallNotification();
    final secs = _computeDuration();
    final active = state.activeCall;

    if (active != null && state.status != CallStatus.idle) {
      final finalStatus =
          state.status == CallStatus.calling ||
              state.status == CallStatus.ringing
          ? CallStatus.missed
          : CallStatus.ended;

      await _callRepo.updateCallStatus(
        callId: active.id,
        status: finalStatus,
        endedAt: DateTime.now(),
        durationSeconds: secs,
      );
    }

    await _callingService.endCall();
    state = CallState(status: CallStatus.ended);
    _scheduleResetToIdle();
  }

  void resetState() {
    _cancelAllTimers();
    _notificationService.cancelIncomingCallNotification();
    state = CallState(status: CallStatus.idle);
  }

  void _scheduleResetToIdle([
    Duration delay = const Duration(milliseconds: 1500),
  ]) {
    Timer(delay, () {
      if (state.status == CallStatus.ended ||
          state.status == CallStatus.rejected ||
          state.status == CallStatus.missed ||
          state.status == CallStatus.failed ||
          state.status == CallStatus.disconnected) {
        state = CallState(status: CallStatus.idle);
      }
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Media controls
  // ──────────────────────────────────────────────────────────────────────────
  void toggleMute() {
    final newMuted = !state.isMuted;
    _callingService.toggleMicrophone(newMuted);
    state = state.copyWith(isMuted: newMuted);
  }

  void toggleCamera() {
    final newCamOff = !state.isCameraOff;
    _callingService.toggleCamera(newCamOff);
    state = state.copyWith(isCameraOff: newCamOff);
  }

  void switchCamera() {
    _callingService.switchCamera();
  }

  void toggleSpeaker() {
    final newSpeaker = !state.isSpeakerOn;
    _callingService.toggleSpeaker(newSpeaker);
    state = state.copyWith(isSpeakerOn: newSpeaker);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────
  Future<void> _updateCallRecord(
    CallStatus status, {
    DateTime? endedAt,
    int? durationSeconds,
  }) async {
    final active = state.activeCall;
    if (active == null) return;
    try {
      await _callRepo.updateCallStatus(
        callId: active.id,
        status: status,
        endedAt: endedAt,
        durationSeconds: durationSeconds,
      );
    } catch (_) {}
  }

  void _cancelAllTimers() {
    _durationTimer?.cancel();
    _ringTimeoutTimer?.cancel();
    _connectingTimeoutTimer?.cancel();
    _durationTimer = null;
    _ringTimeoutTimer = null;
    _connectingTimeoutTimer = null;
  }

  @override
  void dispose() {
    _incomingSubscription?.cancel();
    _rtcStatusSubscription?.cancel();
    _cancelAllTimers();
    _notificationService.cancelIncomingCallNotification();
    super.dispose();
  }
}

final callProvider = StateNotifierProvider<CallNotifier, CallState>((ref) {
  final callingService = ref.watch(callingServiceProvider);
  final callRepo = ref.watch(callRepositoryProvider);
  final permissionService = ref.watch(permissionServiceProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  final currentUser = ref.watch(authProvider).user;

  return CallNotifier(
    callingService,
    callRepo,
    permissionService,
    notificationService,
    currentUser?.id,
  );
});

final callHistoryProvider = FutureProvider.autoDispose<List<CallModel>>((
  ref,
) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  return ref.watch(callRepositoryProvider).getCallHistory(user.id);
});
