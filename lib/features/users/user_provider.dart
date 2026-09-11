import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repositories/user_repository.dart';
import '../../models/user_model.dart';
import '../auth/auth_provider.dart';
import '../../core/errors/app_exception.dart';

class UserListState {
  final bool isLoading;
  final List<UserModel> users;
  final String searchQuery;
  final String? errorMessage;

  UserListState({
    this.isLoading = false,
    this.users = const [],
    this.searchQuery = '',
    this.errorMessage,
  });

  UserListState copyWith({
    bool? isLoading,
    List<UserModel>? users,
    String? searchQuery,
    String? errorMessage,
  }) {
    return UserListState(
      isLoading: isLoading ?? this.isLoading,
      users: users ?? this.users,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage,
    );
  }
}

class UserListNotifier extends StateNotifier<UserListState> {
  final UserRepository _userRepo;
  final String? _currentUserId;

  UserListNotifier(this._userRepo, this._currentUserId)
    : super(UserListState()) {
    loadUsers();
  }

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _userRepo.getUsers(
        searchQuery: state.searchQuery,
        currentUserId: _currentUserId,
      );
      state = state.copyWith(isLoading: false, users: list);
    } catch (e) {
      final appErr = AppException.fromException(e);
      state = state.copyWith(isLoading: false, errorMessage: appErr.message);
    }
  }

  void searchUsers(String query) {
    state = state.copyWith(searchQuery: query);
    loadUsers();
  }

  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? avatarUrl,
  }) async {
    final userId = _currentUserId;
    if (userId == null) return false;
    try {
      await _userRepo.updateProfile(
        userId: userId,
        name: name,
        phone: phone,
        avatarUrl: avatarUrl,
      );
      await loadUsers();
      return true;
    } catch (e) {
      final appErr = AppException.fromException(e);
      state = state.copyWith(errorMessage: appErr.message);
      return false;
    }
  }
}

final userListProvider = StateNotifierProvider<UserListNotifier, UserListState>(
  (ref) {
    final userRepo = ref.watch(userRepositoryProvider);
    final currentUser = ref.watch(authProvider).user;
    return UserListNotifier(userRepo, currentUser?.id);
  },
);
