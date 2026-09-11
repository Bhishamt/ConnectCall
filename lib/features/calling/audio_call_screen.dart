import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'call_provider.dart';
import '../../models/user_model.dart';
import '../../models/call_model.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/theme/app_theme.dart';

class AudioCallScreen extends ConsumerWidget {
  final UserModel contact;

  const AudioCallScreen({super.key, required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callProvider);
    final callNotifier = ref.read(callProvider.notifier);

    ref.listen<CallState>(callProvider, (previous, next) {
      if (next.status == CallStatus.ended ||
          next.status == CallStatus.rejected ||
          next.status == CallStatus.missed ||
          next.status == CallStatus.failed) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Avatar
            CircleAvatar(
              radius: 64,
              backgroundColor: AppColors.primary,
              child: Text(
                contact.name.isNotEmpty ? contact.name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 56,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Name
            Text(
              contact.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            // Status & Duration
            Text(
              callState.status == CallStatus.connected
                  ? DateFormatter.formatDuration(callState.durationSeconds)
                  : callState.status.name.toUpperCase(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: callState.status == CallStatus.connected
                    ? AppColors.callGreen
                    : AppColors.textSecondary,
              ),
            ),
            if (callState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                callState.errorMessage!,
                style: const TextStyle(color: AppColors.callRed, fontSize: 14),
              ),
            ],
            const Spacer(),
            // Controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute Mic
                  IconButton.filledTonal(
                    iconSize: 32,
                    isSelected: callState.isMuted,
                    icon: Icon(callState.isMuted ? Icons.mic_off : Icons.mic),
                    style: IconButton.styleFrom(
                      backgroundColor: callState.isMuted
                          ? AppColors.callRed
                          : AppColors.surfaceLight,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => callNotifier.toggleMute(),
                  ),
                  // End Call Button
                  FloatingActionButton.large(
                    backgroundColor: AppColors.callRed,
                    elevation: 4,
                    onPressed: () => callNotifier.endCall(),
                    child: const Icon(
                      Icons.call_end,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  // Speaker
                  IconButton.filledTonal(
                    iconSize: 32,
                    icon: Icon(
                      callState.isSpeakerOn
                          ? Icons.volume_up
                          : Icons.volume_down,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: callState.isSpeakerOn
                          ? AppColors.primary
                          : AppColors.surfaceLight,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => callNotifier.toggleSpeaker(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
