import 'package:flutter_test/flutter_test.dart';
import 'package:connectcall/models/call_model.dart';
import 'package:connectcall/features/history/call_history_filter.dart';

void main() {
  group('CallHistoryFilter Tests', () {
    final now = DateTime.now();
    final sampleCalls = [
      CallModel(
        id: '1',
        callerId: 'u1',
        calleeId: 'u2',
        callerName: 'Alice',
        calleeName: 'Bob',
        callType: CallType.audio,
        direction: CallDirection.outgoing,
        status: CallStatus.ended,
        startedAt: now,
        durationSeconds: 120,
      ),
      CallModel(
        id: '2',
        callerId: 'u3',
        calleeId: 'u1',
        callerName: 'Charlie',
        calleeName: 'Alice',
        callType: CallType.video,
        direction: CallDirection.incoming,
        status: CallStatus.missed,
        startedAt: now,
        durationSeconds: 0,
      ),
      CallModel(
        id: '3',
        callerId: 'u1',
        calleeId: 'u4',
        callerName: 'Alice',
        calleeName: 'David',
        callType: CallType.video,
        direction: CallDirection.outgoing,
        status: CallStatus.ended,
        startedAt: now,
        durationSeconds: 300,
      ),
    ];

    test('Filter by search query matches caller or callee name', () {
      final filter = const CallHistoryFilter(searchQuery: 'charlie');
      final result = filter.apply(sampleCalls);
      expect(result.length, equals(1));
      expect(result.first.callerName, equals('Charlie'));
    });

    test('Filter by audio call type', () {
      final filter = const CallHistoryFilter(filterType: HistoryFilterType.audio);
      final result = filter.apply(sampleCalls);
      expect(result.length, equals(1));
      expect(result.first.callType, equals(CallType.audio));
    });

    test('Filter by video call type', () {
      final filter = const CallHistoryFilter(filterType: HistoryFilterType.video);
      final result = filter.apply(sampleCalls);
      expect(result.length, equals(2));
    });

    test('Filter by missed calls', () {
      final filter = const CallHistoryFilter(filterType: HistoryFilterType.missed);
      final result = filter.apply(sampleCalls);
      expect(result.length, equals(1));
      expect(result.first.status, equals(CallStatus.missed));
    });

    test('Calculate call stats correctly', () {
      final stats = CallHistoryFilter.calculateStats(sampleCalls);
      expect(stats.totalCalls, equals(3));
      expect(stats.totalDurationSeconds, equals(420));
      expect(stats.missedCalls, equals(1));
      expect(stats.videoCalls, equals(2));
      expect(stats.formattedTotalDuration, equals('7m 0s'));
    });
  });
}
