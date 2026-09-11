import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'call_provider.dart';
import 'audio_call_screen.dart';
import 'video_call_screen.dart';
import '../../models/user_model.dart';
import '../../models/call_model.dart';
import '../../core/theme/app_theme.dart';

class IncomingCallScreen extends ConsumerWidget {
  const IncomingCallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callProvider);
    final callNotifier = ref.read(callProvider.notifier);
    final activeCall = callState.activeCall;

    if (activeCall == null) return const SizedBox.shrink();

    final callerName = activeCall.callerName ?? 'Incoming User';
    final isVideo = activeCall.callType == CallType.video;

    ref.listen<CallState>(callProvider, (previous, next) {
      if (next.status == CallStatus.connected) {
        final contact = UserModel(
          id: activeCall.callerId,
          name: callerName,
          email: '',
          avatarUrl: activeCall.callerAvatar,
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => isVideo
                ? VideoCallScreen(contact: contact)
                : AudioCallScreen(contact: contact),
          ),
        );
      } else if (next.status == CallStatus.ended ||
          next.status == CallStatus.rejected ||
          next.status == CallStatus.missed) {
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
            CircleAvatar(
              radius: 64,
              backgroundColor: AppColors.primary,
              child: Text(
                callerName.isNotEmpty ? callerName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize: 56,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(callerName, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isVideo ? Icons.videocam : Icons.call,
                  color: AppColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Incoming ${isVideo ? 'Video' : 'Audio'} Call...',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Decline Button
                  Column(
                    children: [
                      FloatingActionButton.large(
                        heroTag: 'decline_btn',
                        backgroundColor: AppColors.callRed,
                        onPressed: () => callNotifier.rejectCall(),
                        child: const Icon(
                          Icons.call_end,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Decline',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  // Accept Button
                  Column(
                    children: [
                      FloatingActionButton.large(
                        heroTag: 'accept_btn',
                        backgroundColor: AppColors.callGreen,
                        onPressed: () => callNotifier.acceptCall(),
                        child: Icon(
                          isVideo ? Icons.videocam : Icons.call,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Accept',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
