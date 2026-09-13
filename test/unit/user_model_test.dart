import 'package:flutter_test/flutter_test.dart';
import 'package:connectcall/models/user_model.dart';

void main() {
  group('UserModel Tests', () {
    final now = DateTime.now();

    test('fromJson parses full user profile correctly', () {
      final json = {
        'id': 'usr-100',
        'name': 'John Doe',
        'email': 'john@example.com',
        'phone': '+1234567890',
        'avatar_url': 'https://example.com/avatar.png',
        'is_online': true,
        'last_seen': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      };

      final user = UserModel.fromJson(json);

      expect(user.id, equals('usr-100'));
      expect(user.name, equals('John Doe'));
      expect(user.email, equals('john@example.com'));
      expect(user.phone, equals('+1234567890'));
      expect(user.avatarUrl, equals('https://example.com/avatar.png'));
      expect(user.isOnline, isTrue);
      expect(user.effectiveOnline, isTrue);
    });

    test('fromJson provides safe fallbacks for optional fields', () {
      final json = {
        'id': 'usr-101',
      };

      final user = UserModel.fromJson(json);

      expect(user.id, equals('usr-101'));
      expect(user.name, equals('Unknown'));
      expect(user.email, isEmpty);
      expect(user.phone, isNull);
      expect(user.avatarUrl, isNull);
      expect(user.isOnline, isFalse);
    });

    test('toJson serializes user profile accurately', () {
      final user = UserModel(
        id: 'usr-200',
        name: 'Jane Smith',
        email: 'jane@example.com',
        isOnline: true,
        lastSeen: now,
      );

      final json = user.toJson();

      expect(json['id'], equals('usr-200'));
      expect(json['name'], equals('Jane Smith'));
      expect(json['email'], equals('jane@example.com'));
      expect(json['is_online'], isTrue);
      expect(json['last_seen'], equals(now.toIso8601String()));
    });

    test('copyWith produces updated instance preserving unmodified attributes', () {
      final user = UserModel(
        id: 'usr-300',
        name: 'Alex',
        email: 'alex@example.com',
        isOnline: false,
      );

      final updated = user.copyWith(
        isOnline: true,
        avatarUrl: 'https://example.com/new_avatar.png',
      );

      expect(updated.id, equals('usr-300'));
      expect(updated.name, equals('Alex'));
      expect(updated.email, equals('alex@example.com'));
      expect(updated.isOnline, isTrue);
      expect(updated.avatarUrl, equals('https://example.com/new_avatar.png'));
    });
  });
}
