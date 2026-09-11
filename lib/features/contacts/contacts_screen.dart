import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../users/user_provider.dart';
import '../calling/call_provider.dart';
import '../calling/audio_call_screen.dart';
import '../calling/video_call_screen.dart';
import '../../models/user_model.dart';
import '../../models/call_model.dart';
import '../../core/theme/app_theme.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatLastSeen(UserModel user) {
    if (user.lastSeen == null) return 'Offline';
    final diff = DateTime.now().difference(user.lastSeen!);
    if (diff.inMinutes < 1) return 'Last seen just now';
    if (diff.inMinutes < 60) return 'Last seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Last seen ${diff.inHours}h ago';
    return 'Last seen ${diff.inDays}d ago';
  }

  void _startAudioCall(UserModel contact) async {
    final callNotifier = ref.read(callProvider.notifier);
    final success = await callNotifier.initiateCall(
      recipient: contact,
      callType: CallType.audio,
    );

    if (success && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => AudioCallScreen(contact: contact)),
      );
    } else if (mounted) {
      final state = ref.read(callProvider);
      if (state.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: AppColors.callRed,
          ),
        );
      }
    }
  }

  void _startVideoCall(UserModel contact) async {
    final callNotifier = ref.read(callProvider.notifier);
    final success = await callNotifier.initiateCall(
      recipient: contact,
      callType: CallType.video,
    );

    if (success && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => VideoCallScreen(contact: contact)),
      );
    } else if (mounted) {
      final state = ref.read(callProvider);
      if (state.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: AppColors.callRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userListState = ref.watch(userListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  ref.read(userListProvider.notifier).searchUsers(value),
              decoration: InputDecoration(
                hintText: 'Search contacts by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(userListProvider.notifier).searchUsers('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(child: _buildContent(userListState)),
        ],
      ),
    );
  }

  Widget _buildContent(UserListState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.callRed),
            const SizedBox(height: 16),
            Text(
              state.errorMessage!,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(userListProvider.notifier).loadUsers(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              state.searchQuery.isEmpty
                  ? 'No other contacts found.'
                  : 'No users matching "${state.searchQuery}"',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(userListProvider.notifier).loadUsers(),
      child: ListView.separated(
        itemCount: state.users.length,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final user = state.users[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: user.effectiveOnline
                            ? AppColors.onlineGreen
                            : AppColors.offlineGrey,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.surface, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(
                user.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                user.effectiveOnline ? 'Online' : _formatLastSeen(user),
                style: TextStyle(
                  color: user.effectiveOnline
                      ? AppColors.onlineGreen
                      : AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.call, color: AppColors.callGreen),
                    onPressed: () => _startAudioCall(user),
                    tooltip: 'Audio Call',
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam, color: AppColors.primary),
                    onPressed: () => _startVideoCall(user),
                    tooltip: 'Video Call',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
