import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors/app_exception.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      return response;
    } catch (e) {
      throw AppException.fromException(e);
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // NOTE: is_online / last_seen is managed by PresenceService, not here.
      return response;
    } catch (e) {
      throw AppException.fromException(e);
    }
  }

  Future<void> signOut() async {
    try {
      // NOTE: PresenceService.stop() already sets is_online=false before this
      // is called from AuthNotifier.logout().
      await _supabase.auth.signOut();
    } catch (e) {
      throw AppException.fromException(e);
    }
  }
}
