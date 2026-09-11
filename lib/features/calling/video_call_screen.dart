import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'call_provider.dart';
import '../../models/user_model.dart';
import '../../models/call_model.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/theme/app_theme.dart';

class VideoCallScreen extends ConsumerWidget {
  final UserModel contact;

  const VideoCallScreen({super.key, required this.contact});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(callProvider);
    final callNotifier = ref.read(callProvider.notifier);
    final callingService = ref.watch(callingServiceProvider);

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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Remote Video (Full Screen)
          Positioned.fill(
            child: callState.status == CallStatus.connected
                ? RTCVideoView(
                    callingService.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            contact.name.isNotEmpty
                                ? contact.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 48,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          contact.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          callState.status.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // 2. Local PIP Camera Preview
          if (!callState.isCameraOff)
            Positioned(
              right: 16,
              top: 48,
              width: 120,
              height: 160,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, width: 2),
                  color: Colors.black45,
                ),
                clipBehavior: Clip.antiAlias,
                child: RTCVideoView(
                  callingService.localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),

          // 3. Header Info Overlay
          Positioned(
            left: 16,
            top: 48,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (callState.status == CallStatus.connected)
                    Text(
                      '• ${DateFormatter.formatDuration(callState.durationSeconds)}',
                      style: const TextStyle(
                        color: AppColors.callGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 4. Bottom Call Controls Overlay
          Positioned(
            left: 16,
            right: 16,
            bottom: 32,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute Mic
                  IconButton(
                    icon: Icon(
                      callState.isMuted ? Icons.mic_off : Icons.mic,
                      color: Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: callState.isMuted
                          ? AppColors.callRed
                          : AppColors.surfaceLight,
                    ),
                    onPressed: () => callNotifier.toggleMute(),
                  ),
                  // Camera On/Off
                  IconButton(
                    icon: Icon(
                      callState.isCameraOff
                          ? Icons.videocam_off
                          : Icons.videocam,
                      color: Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: callState.isCameraOff
                          ? AppColors.callRed
                          : AppColors.surfaceLight,
                    ),
                    onPressed: () => callNotifier.toggleCamera(),
                  ),
                  // End Call Button
                  FloatingActionButton(
                    backgroundColor: AppColors.callRed,
                    elevation: 4,
                    onPressed: () => callNotifier.endCall(),
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                  // Switch Camera
                  IconButton(
                    icon: const Icon(Icons.cameraswitch, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceLight,
                    ),
                    onPressed: () => callNotifier.switchCamera(),
                  ),
                  // Speaker
                  IconButton(
                    icon: Icon(
                      callState.isSpeakerOn
                          ? Icons.volume_up
                          : Icons.volume_down,
                      color: Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: callState.isSpeakerOn
                          ? AppColors.primary
                          : AppColors.surfaceLight,
                    ),
                    onPressed: () => callNotifier.toggleSpeaker(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
