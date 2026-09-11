import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calling/call_provider.dart';
import '../../models/call_model.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/theme/app_theme.dart';

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(callHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Call History'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: historyAsync.when(
        data: (calls) {
          if (calls.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off_rounded,
                    size: 64,
                    color: AppColors.textMuted,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No call history yet',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(callHistoryProvider),
            child: ListView.separated(
              itemCount: calls.length,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final call = calls[index];
                final isOutgoing = call.direction == CallDirection.outgoing;
                final isMissed =
                    call.status == CallStatus.missed ||
                    call.status == CallStatus.rejected;
                final contactName = isOutgoing
                    ? (call.calleeName ?? 'User')
                    : (call.callerName ?? 'User');

                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isMissed
                          ? AppColors.callRed.withValues(alpha: 0.2)
                          : AppColors.primary.withValues(alpha: 0.2),
                      child: Icon(
                        call.callType == CallType.video
                            ? Icons.videocam
                            : Icons.call,
                        color: isMissed ? AppColors.callRed : AppColors.primary,
                      ),
                    ),
                    title: Text(
                      contactName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Icon(
                          isOutgoing ? Icons.call_made : Icons.call_received,
                          size: 14,
                          color: isMissed
                              ? AppColors.callRed
                              : (isOutgoing
                                    ? AppColors.secondary
                                    : AppColors.primary),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          call.status.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isMissed
                                ? AppColors.callRed
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${DateFormatter.formatCallTime(call.startedAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      call.durationSeconds > 0
                          ? DateFormatter.formatDuration(call.durationSeconds)
                          : '--:--',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.callRed,
              ),
              const SizedBox(height: 16),
              Text(
                err.toString(),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(callHistoryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
