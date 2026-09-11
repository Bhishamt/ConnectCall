import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/call_model.dart';
import '../core/errors/app_exception.dart';

class CallRepository {
  final SupabaseClient _supabase;

  CallRepository(this._supabase);

  /// Atomically initiates a call session via PostgreSQL `start_call_atomic` RPC.
  /// Guarantees caller & callee busy locking and prevents race conditions.
  Future<CallModel> createCallSession(CallModel call) async {
    try {
      final res = await _supabase.rpc(
        'start_call_atomic',
        params: {
          'p_call_id': call.id,
          'p_callee_id': call.calleeId,
          'p_call_type': call.callType.name,
        },
      );

      final result = res.toString();
      if (result == 'BUSY') {
        throw AppException('User is currently on another call.', 'busy');
      } else if (result == 'ALREADY_IN_CALL') {
        throw AppException(
          'You are already in an active call.',
          'already_in_call',
        );
      } else if (result == 'USER_NOT_FOUND') {
        throw AppException('Recipient user not found.', 'user_not_found');
      } else if (result != 'SUCCESS') {
        throw AppException('Failed to start call ($result)', 'call_failed');
      }

      return call;
    } catch (e) {
      throw AppException.fromException(e);
    }
  }

  Future<void> updateCallStatus({
    required String callId,
    required CallStatus status,
    DateTime? answeredAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) async {
    try {
      final updates = <String, dynamic>{'status': status.name};
      if (answeredAt != null) {
        updates['answered_at'] = answeredAt.toIso8601String();
      }
      if (endedAt != null) {
        updates['ended_at'] = endedAt.toIso8601String();
      }
      if (durationSeconds != null) {
        updates['duration_seconds'] = durationSeconds;
      }

      await _supabase.from('call_sessions').update(updates).eq('id', callId);
    } catch (e) {
      throw AppException.fromException(e);
    }
  }

  Future<List<CallModel>> getCallHistory(String userId) async {
    try {
      final response = await _supabase
          .from('call_sessions')
          .select('''
            *,
            caller:caller_id (id, name, avatar_url),
            callee:callee_id (id, name, avatar_url)
          ''')
          .or('caller_id.eq.$userId,callee_id.eq.$userId')
          .order('started_at', ascending: false);

      final list = (response as List).map((json) {
        return CallModel.fromJson(
          json as Map<String, dynamic>,
          currentUserId: userId,
        );
      }).toList();

      return list;
    } catch (e) {
      throw AppException.fromException(e);
    }
  }

  Stream<List<CallModel>> streamIncomingCalls(String userId) {
    return _supabase
        .from('call_sessions')
        .stream(primaryKey: ['id'])
        .eq('callee_id', userId)
        .map((list) {
          return list
              .where(
                (data) =>
                    data['status'] == 'calling' || data['status'] == 'ringing',
              )
              .map((data) => CallModel.fromJson(data, currentUserId: userId))
              .toList();
        });
  }
}
