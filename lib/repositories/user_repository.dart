import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../core/errors/app_exception.dart';

class UserRepository {
  final SupabaseClient _supabase;

  UserRepository(this._supabase);

  Future<List<UserModel>> getUsers({
    String? searchQuery,
    String? currentUserId,
  }) async {
    try {
      var builder = _supabase.from('profiles').select();

      if (currentUserId != null) {
        builder = builder.neq('id', currentUserId);
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        builder = builder.ilike('name', '%${searchQuery.trim()}%');
      }

      final response = await builder.order('name', ascending: true);
      final list = (response as List)
          .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      throw AppException.fromException(e);
    }
  }

  Future<UserModel> getUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return UserModel.fromJson(response);
    } catch (e) {
      throw AppException.fromException(e);
    }
  }

  Future<void> updateProfile({
    required String userId,
    String? name,
    String? phone,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await _supabase.from('profiles').update(updates).eq('id', userId);
    } catch (e) {
      throw AppException.fromException(e);
    }
  }

  Future<void> setOnlineStatus(String userId, bool isOnline) async {
    try {
      await _supabase
          .from('profiles')
          .update({
            'is_online': isOnline,
            'last_seen': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);
    } catch (_) {
      // Ignore background status errors
    }
  }

  Stream<List<UserModel>> streamUsers({String? currentUserId}) {
    return _supabase.from('profiles').stream(primaryKey: ['id']).map((list) {
      return list
          .where((data) => currentUserId == null || data['id'] != currentUserId)
          .map((data) => UserModel.fromJson(data))
          .toList();
    });
  }
}
