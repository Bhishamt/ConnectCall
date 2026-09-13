import 'package:flutter_test/flutter_test.dart';
import 'package:connectcall/models/call_model.dart';

void main() {
  group('CallModel Tests', () {
    final now = DateTime.now();

    test('fromJson parses incoming call correctly', () {
      final json = {
        'id': 'call-123',
        'caller_id': 'user-caller',
        'callee_id': 'user-callee',
        'caller_name': 'Alice',
        'callee_name': 'Bob',
        'call_type': 'video',
        'status': 'connected',
        'started_at': now.toIso8601String(),
        'duration_seconds': 120,
      };

      final model = CallModel.fromJson(json, currentUserId: 'user-callee');

      expect(model.id, equals('call-123'));
      expect(model.callerId, equals('user-caller'));
      expect(model.calleeId, equals('user-callee'));
      expect(model.callerName, equals('Alice'));
      expect(model.callType, equals(CallType.video));
      expect(model.direction, equals(CallDirection.incoming));
      expect(model.status, equals(CallStatus.connected));
      expect(model.durationSeconds, equals(120));
    });

    test('fromJson parses outgoing call correctly', () {
      final json = {
        'id': 'call-456',
        'caller_id': 'my-id',
        'callee_id': 'other-id',
        'call_type': 'audio',
        'status': 'calling',
        'started_at': now.toIso8601String(),
      };

      final model = CallModel.fromJson(json, currentUserId: 'my-id');

      expect(model.direction, equals(CallDirection.outgoing));
      expect(model.callType, equals(CallType.audio));
      expect(model.status, equals(CallStatus.calling));
    });

    test('toJson serializes properties correctly', () {
      final model = CallModel(
        id: 'call-789',
        callerId: 'user-a',
        calleeId: 'user-b',
        callType: CallType.video,
        direction: CallDirection.outgoing,
        status: CallStatus.ended,
        startedAt: now,
        durationSeconds: 45,
      );

      final json = model.toJson();

      expect(json['id'], equals('call-789'));
      expect(json['caller_id'], equals('user-a'));
      expect(json['callee_id'], equals('user-b'));
      expect(json['call_type'], equals('video'));
      expect(json['direction'], equals('outgoing'));
      expect(json['status'], equals('ended'));
      expect(json['duration_seconds'], equals(45));
    });

    test('copyWith updates specified fields only', () {
      final original = CallModel(
        id: 'call-1',
        callerId: 'user-1',
        calleeId: 'user-2',
        callType: CallType.audio,
        direction: CallDirection.incoming,
        status: CallStatus.ringing,
        startedAt: now,
      );

      final updated = original.copyWith(
        status: CallStatus.connected,
        durationSeconds: 300,
      );

      expect(updated.id, equals(original.id));
      expect(updated.status, equals(CallStatus.connected));
      expect(updated.durationSeconds, equals(300));
      expect(updated.callType, equals(CallType.audio));
    });
  });
}
