import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectcall/core/theme/app_theme.dart';
import 'package:connectcall/models/user_model.dart';
import 'package:connectcall/models/call_model.dart';
import 'package:connectcall/services/presence_service.dart';

void main() {
  testWidgets('ConnectCall Theme & UI Component smoke test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: Center(child: Text('ConnectCall'))),
        ),
      ),
    );

    expect(find.text('ConnectCall'), findsOneWidget);
  });

  test('UserModel JSON serialization and effectiveOnline test', () {
    final now = DateTime.now().toUtc();
    final recentUser = UserModel(
      id: 'test-user-123',
      name: 'Alice Smith',
      email: 'alice@example.com',
      isOnline: true,
      lastSeen: now.subtract(const Duration(minutes: 1)),
    );

    expect(recentUser.effectiveOnline, isTrue);

    final staleUser = UserModel(
      id: 'test-user-456',
      name: 'Bob Jones',
      email: 'bob@example.com',
      isOnline: true,
      lastSeen: now.subtract(const Duration(minutes: 10)),
    );

    expect(staleUser.effectiveOnline, isFalse);

    final offlineUser = UserModel(
      id: 'test-user-789',
      name: 'Charlie Brown',
      email: 'charlie@example.com',
      isOnline: false,
      lastSeen: now,
    );

    expect(offlineUser.effectiveOnline, isFalse);

    final json = recentUser.toJson();
    expect(json['id'], 'test-user-123');
    expect(json['name'], 'Alice Smith');
    expect(json['email'], 'alice@example.com');
    expect(json['is_online'], true);

    final deserialized = UserModel.fromJson(json);
    expect(deserialized.id, recentUser.id);
    expect(deserialized.name, recentUser.name);
    expect(deserialized.email, recentUser.email);
    expect(deserialized.isOnline, recentUser.isOnline);
  });

  test('CallModel direction and status parsing test', () {
    final now = DateTime.now();
    final call = CallModel(
      id: 'call-456',
      callerId: 'user-a',
      calleeId: 'user-b',
      callType: CallType.video,
      direction: CallDirection.outgoing,
      status: CallStatus.connected,
      startedAt: now,
      durationSeconds: 45,
    );

    final json = call.toJson();
    expect(json['id'], 'call-456');
    expect(json['caller_id'], 'user-a');
    expect(json['callee_id'], 'user-b');
    expect(json['call_type'], 'video');
    expect(json['status'], 'connected');
    expect(json['duration_seconds'], 45);

    // Direction calculation for caller
    final callerPerspective = CallModel.fromJson(json, currentUserId: 'user-a');
    expect(callerPerspective.direction, CallDirection.outgoing);

    // Direction calculation for callee
    final calleePerspective = CallModel.fromJson(json, currentUserId: 'user-b');
    expect(calleePerspective.direction, CallDirection.incoming);
  });

  test('CallStatus contains all required 13 states', () {
    const expectedStates = [
      CallStatus.idle,
      CallStatus.calling,
      CallStatus.ringing,
      CallStatus.connecting,
      CallStatus.connected,
      CallStatus.inCall,
      CallStatus.ending,
      CallStatus.ended,
      CallStatus.rejected,
      CallStatus.missed,
      CallStatus.busy,
      CallStatus.failed,
      CallStatus.disconnected,
    ];

    for (final state in expectedStates) {
      expect(CallStatus.values.contains(state), isTrue);
    }
  });

  test('PresenceService staleness helper calculates correctly', () {
    final now = DateTime.now().toUtc();
    expect(
      PresenceService.isEffectivelyOnline(
        isOnline: true,
        lastSeen: now.subtract(const Duration(minutes: 2)),
      ),
      isTrue,
    );

    expect(
      PresenceService.isEffectivelyOnline(
        isOnline: true,
        lastSeen: now.subtract(const Duration(minutes: 6)),
      ),
      isFalse,
    );

    expect(
      PresenceService.isEffectivelyOnline(
        isOnline: false,
        lastSeen: now.subtract(const Duration(seconds: 10)),
      ),
      isFalse,
    );
  });
}
