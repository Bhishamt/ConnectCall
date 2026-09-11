enum CallType { audio, video }

enum CallDirection { incoming, outgoing }

enum CallStatus {
  idle,
  calling,
  ringing,
  connecting,
  connected,
  inCall,
  ending,
  ended,
  rejected,
  missed,
  busy,
  failed,
  disconnected,
}

class CallModel {
  final String id;
  final String callerId;
  final String calleeId;
  final String? callerName;
  final String? calleeName;
  final String? callerAvatar;
  final String? calleeAvatar;
  final CallType callType;
  final CallDirection direction;
  final CallStatus status;
  final DateTime startedAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final int durationSeconds;

  CallModel({
    required this.id,
    required this.callerId,
    required this.calleeId,
    this.callerName,
    this.calleeName,
    this.callerAvatar,
    this.calleeAvatar,
    required this.callType,
    required this.direction,
    required this.status,
    required this.startedAt,
    this.answeredAt,
    this.endedAt,
    this.durationSeconds = 0,
  });

  factory CallModel.fromJson(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) {
    final callerId = json['caller_id'] as String;
    final isOutgoing = currentUserId != null && callerId == currentUserId;

    CallType parseType(String typeStr) {
      return typeStr == 'video' ? CallType.video : CallType.audio;
    }

    CallStatus parseStatus(String statusStr) {
      return CallStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => CallStatus.ended,
      );
    }

    return CallModel(
      id: json['id'] as String,
      callerId: callerId,
      calleeId: json['callee_id'] as String,
      callerName: json['caller'] != null
          ? json['caller']['name'] as String?
          : json['caller_name'] as String?,
      calleeName: json['callee'] != null
          ? json['callee']['name'] as String?
          : json['callee_name'] as String?,
      callerAvatar: json['caller'] != null
          ? json['caller']['avatar_url'] as String?
          : json['caller_avatar'] as String?,
      calleeAvatar: json['callee'] != null
          ? json['callee']['avatar_url'] as String?
          : json['callee_avatar'] as String?,
      callType: parseType(json['call_type'] as String? ?? 'audio'),
      direction: isOutgoing ? CallDirection.outgoing : CallDirection.incoming,
      status: parseStatus(json['status'] as String? ?? 'ended'),
      startedAt: DateTime.parse(
        json['started_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      answeredAt: json['answered_at'] != null
          ? DateTime.tryParse(json['answered_at'].toString())
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.tryParse(json['ended_at'].toString())
          : null,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caller_id': callerId,
      'callee_id': calleeId,
      'call_type': callType.name,
      'direction': direction.name,
      'status': status.name,
      'started_at': startedAt.toIso8601String(),
      'answered_at': answeredAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
    };
  }

  CallModel copyWith({
    String? id,
    String? callerId,
    String? calleeId,
    String? callerName,
    String? calleeName,
    String? callerAvatar,
    String? calleeAvatar,
    CallType? callType,
    CallDirection? direction,
    CallStatus? status,
    DateTime? startedAt,
    DateTime? answeredAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) {
    return CallModel(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      calleeId: calleeId ?? this.calleeId,
      callerName: callerName ?? this.callerName,
      calleeName: calleeName ?? this.calleeName,
      callerAvatar: callerAvatar ?? this.callerAvatar,
      calleeAvatar: calleeAvatar ?? this.calleeAvatar,
      callType: callType ?? this.callType,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      answeredAt: answeredAt ?? this.answeredAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }
}
