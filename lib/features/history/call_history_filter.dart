import '../../models/call_model.dart';

enum HistoryFilterType { all, audio, video, missed }

class CallHistoryFilter {
  final String searchQuery;
  final HistoryFilterType filterType;

  const CallHistoryFilter({
    this.searchQuery = '',
    this.filterType = HistoryFilterType.all,
  });

  CallHistoryFilter copyWith({
    String? searchQuery,
    HistoryFilterType? filterType,
  }) {
    return CallHistoryFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      filterType: filterType ?? this.filterType,
    );
  }

  List<CallModel> apply(List<CallModel> calls) {
    return calls.where((call) {
      // 1. Search Query
      if (searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final caller = (call.callerName ?? '').toLowerCase();
        final callee = (call.calleeName ?? '').toLowerCase();
        if (!caller.contains(q) && !callee.contains(q)) {
          return false;
        }
      }

      // 2. Filter Type
      switch (filterType) {
        case HistoryFilterType.audio:
          return call.callType == CallType.audio;
        case HistoryFilterType.video:
          return call.callType == CallType.video;
        case HistoryFilterType.missed:
          return call.status == CallStatus.missed ||
              call.status == CallStatus.rejected;
        case HistoryFilterType.all:
        default:
          return true;
      }
    }).toList();
  }

  static CallHistoryStats calculateStats(List<CallModel> calls) {
    int totalCalls = calls.length;
    int totalDurationSeconds = 0;
    int missedCalls = 0;
    int videoCalls = 0;

    for (final call in calls) {
      totalDurationSeconds += call.durationSeconds;
      if (call.status == CallStatus.missed || call.status == CallStatus.rejected) {
        missedCalls++;
      }
      if (call.callType == CallType.video) {
        videoCalls++;
      }
    }

    return CallHistoryStats(
      totalCalls: totalCalls,
      totalDurationSeconds: totalDurationSeconds,
      missedCalls: missedCalls,
      videoCalls: videoCalls,
    );
  }
}

class CallHistoryStats {
  final int totalCalls;
  final int totalDurationSeconds;
  final int missedCalls;
  final int videoCalls;

  const CallHistoryStats({
    required this.totalCalls,
    required this.totalDurationSeconds,
    required this.missedCalls,
    required this.videoCalls,
  });

  String get formattedTotalDuration {
    final minutes = totalDurationSeconds ~/ 60;
    final seconds = totalDurationSeconds % 60;
    if (minutes > 60) {
      final hours = minutes ~/ 60;
      final remMinutes = minutes % 60;
      return '${hours}h ${remMinutes}m';
    }
    return '${minutes}m ${seconds}s';
  }
}
