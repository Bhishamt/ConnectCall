import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contacts/contacts_screen.dart';
import '../history/call_history_screen.dart';
import '../profile/profile_screen.dart';
import '../calling/call_provider.dart';
import '../calling/incoming_call_screen.dart';
import '../calling/audio_call_screen.dart';
import '../calling/video_call_screen.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/theme/app_theme.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  StreamSubscription<String>? _notificationTapSub;

  final List<Widget> _pages = const [
    ContactsScreen(),
    CallHistoryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    final notifService = ref.read(notificationServiceProvider);
    _notificationTapSub = notifService.onNotificationTap.listen((payload) {
      if (mounted) {
        _reopenActiveCallScreen();
      }
    });
  }

  @override
  void dispose() {
    _notificationTapSub?.cancel();
    super.dispose();
  }

  void _reopenActiveCallScreen() {
    final callState = ref.read(callProvider);
    final activeCall = callState.activeCall;
    if (activeCall == null) return;

    final contact = UserModel(
      id: activeCall.direction == CallDirection.outgoing
          ? activeCall.calleeId
          : activeCall.callerId,
      name: activeCall.calleeName ?? activeCall.callerName ?? 'User',
      email: '',
      avatarUrl: activeCall.calleeAvatar ?? activeCall.callerAvatar,
    );

    final isVideo = activeCall.callType == CallType.video;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isVideo
            ? VideoCallScreen(contact: contact)
            : AudioCallScreen(contact: contact),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(callProvider);
    final callNotifier = ref.read(callProvider.notifier);

    // Global Incoming Call Listener
    ref.listen<CallState>(callProvider, (previous, next) {
      if (next.status == CallStatus.ringing &&
          previous?.status != CallStatus.ringing) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const IncomingCallScreen()));
      }
    });

    final isActiveCall =
        callState.status == CallStatus.calling ||
        callState.status == CallStatus.connecting ||
        callState.status == CallStatus.connected;

    final activeCall = callState.activeCall;
    final contactName =
        activeCall?.calleeName ?? activeCall?.callerName ?? 'Contact';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _pages),
          ),
          // Active Call Recoverable Banner
          if (isActiveCall)
            Material(
              color: AppColors.surface,
              elevation: 8,
              child: InkWell(
                onTap: _reopenActiveCallScreen,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: callState.status == CallStatus.connected
                            ? AppColors.callGreen
                            : AppColors.primary,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          contactName.isNotEmpty
                              ? contactName[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              contactName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              callState.status == CallStatus.connected
                                  ? 'Active call • ${DateFormatter.formatDuration(callState.durationSeconds)}'
                                  : 'Connecting...',
                              style: TextStyle(
                                color: callState.status == CallStatus.connected
                                    ? AppColors.callGreen
                                    : AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.fullscreen, color: Colors.white),
                        tooltip: 'Expand call controls',
                        onPressed: _reopenActiveCallScreen,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.call_end,
                          color: AppColors.callRed,
                        ),
                        tooltip: 'End call',
                        onPressed: () => callNotifier.endCall(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Contacts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            activeIcon: Icon(Icons.history_toggle_off),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
