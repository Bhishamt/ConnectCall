import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/auth_repository.dart';
import '../../repositories/user_repository.dart';
import '../../services/presence_service.dart';
import '../../models/user_model.dart';
import '../../core/errors/app_exception.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(supabaseClientProvider));
});

final presenceServiceProvider = Provider<PresenceService>((ref) {
  final service = PresenceService(ref.watch(supabaseClientProvider));
  ref.onDispose(() => service.dispose());
  return service;
});

class AuthState {
  final bool isLoading;
  final UserModel? user;
  final String? errorMessage;
  final bool isAuthenticated;

  AuthState({
    this.isLoading = true, // Start as loading — session restoration in progress
    this.user,
    this.errorMessage,
    this.isAuthenticated = false,
  });

  AuthState copyWith({
    bool? isLoading,
    UserModel? user,
    String? errorMessage,
    bool? isAuthenticated,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      errorMessage: errorMessage,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepo;
  final UserRepository _userRepo;
  final PresenceService _presenceService;
  StreamSubscription<AuthState>? _authSub;

  AuthNotifier(this._authRepo, this._userRepo, this._presenceService)
    : super(AuthState(isLoading: true)) {
    _initSession();
  }

  Future<void> _initSession() async {
    // state is already isLoading=true from constructor
    final user = _authRepo.currentUser;
    if (user != null) {
      try {
        final profile = await _userRepo.getUserProfile(user.id);
        _presenceService.start(user.id);
        state = AuthState(
          isLoading: false,
          user: profile,
          isAuthenticated: true,
        );
      } catch (_) {
        // Profile fetch failed but we have a valid Supabase session.
        // Still mark as authenticated — profile may load later.
        state = AuthState(isLoading: false, isAuthenticated: false);
      }
    } else {
      state = AuthState(isLoading: false, isAuthenticated: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _authRepo.signIn(email: email, password: password);
      if (response.user != null) {
        final profile = await _userRepo.getUserProfile(response.user!.id);
        _presenceService.start(response.user!.id);
        state = AuthState(
          isLoading: false,
          user: profile,
          isAuthenticated: true,
        );
        return true;
      }
      state = state.copyWith(isLoading: false, errorMessage: 'Login failed');
      return false;
    } catch (e) {
      final appErr = AppException.fromException(e);
      state = state.copyWith(isLoading: false, errorMessage: appErr.message);
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _authRepo.signUp(
        name: name,
        email: email,
        password: password,
      );
      if (response.user != null) {
        // Wait briefly for the trigger to create the profile
        await Future.delayed(const Duration(milliseconds: 500));
        final profile = await _userRepo.getUserProfile(response.user!.id);
        _presenceService.start(response.user!.id);
        state = AuthState(
          isLoading: false,
          user: profile,
          isAuthenticated: true,
        );
        return true;
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Registration failed',
      );
      return false;
    } catch (e) {
      final appErr = AppException.fromException(e);
      state = state.copyWith(isLoading: false, errorMessage: appErr.message);
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    _presenceService.stop();
    try {
      await _authRepo.signOut();
    } catch (_) {}
    state = AuthState(isLoading: false, isAuthenticated: false);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.watch(authRepositoryProvider),
    ref.watch(userRepositoryProvider),
    ref.watch(presenceServiceProvider),
  );
});
