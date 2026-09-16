import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calling/call_provider.dart';
import '../../models/call_model.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/theme/app_theme.dart';

import 'call_history_filter.dart';

final historyFilterStateProvider =
    StateProvider.autoDispose<CallHistoryFilter>((ref) => const CallHistoryFilter());

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(callHistoryProvider);
    final filter = ref.watch(historyFilterStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Call History'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: historyAsync.when(
        data: (allCalls) {
          final stats = CallHistoryFilter.calculateStats(allCalls);
          final calls = filter.apply(allCalls);

          return Column(
            children: [
              // Search & Filter Header
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (val) {
                        ref
                            .read(historyFilterStateProvider.notifier)
                            .state = filter.copyWith(searchQuery: val);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by name...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: HistoryFilterType.values.map((type) {
                          final isSelected = filter.filterType == type;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(
                                type.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.background,
                              onSelected: (_) {
                                ref
                                    .read(historyFilterStateProvider.notifier)
                                    .state = filter.copyWith(filterType: type);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              // Stats Banner
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Total', '${stats.totalCalls}'),
                    _buildStatItem('Duration', stats.formattedTotalDuration),
                    _buildStatItem('Missed', '${stats.missedCalls}', isError: true),
                  ],
                ),
              ),

              // History List
              Expanded(
                child: calls.isEmpty
                    ? const Center(
                        child: Text(
                          'No matching calls found',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async => ref.refresh(callHistoryProvider),
                        child: ListView.separated(
                          itemCount: calls.length,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final call = calls[index];
                            final isOutgoing =
                                call.direction == CallDirection.outgoing;
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
                                    color: isMissed
                                        ? AppColors.callRed
                                        : AppColors.primary,
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
                                      isOutgoing
                                          ? Icons.call_made
                                          : Icons.call_received,
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
                                      ? DateFormatter.formatDuration(
                                          call.durationSeconds)
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
                      ),
              ),
            ],
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

  Widget _buildStatItem(String label, String value, {bool isError = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isError ? AppColors.callRed : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
