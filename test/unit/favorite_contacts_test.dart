import 'package:flutter_test/flutter_test.dart';
import 'package:connectcall/models/user_model.dart';

void main() {
  group('Favorite Contacts & UserModel Tests', () {
    test('UserModel isFavorite defaults to false', () {
      final user = UserModel(
        id: 'u1',
        name: 'John',
        email: 'john@example.com',
      );
      expect(user.isFavorite, isFalse);
    });

    test('UserModel fromJson/toJson preserves isFavorite flag', () {
      final user = UserModel(
        id: 'u2',
        name: 'Sarah',
        email: 'sarah@example.com',
        isFavorite: true,
      );

      final json = user.toJson();
      expect(json['is_favorite'], isTrue);

      final deserialized = UserModel.fromJson(json);
      expect(deserialized.isFavorite, isTrue);
    });

    test('UserModel copyWith toggles isFavorite correctly', () {
      final user = UserModel(
        id: 'u3',
        name: 'Dave',
        email: 'dave@example.com',
        isFavorite: false,
      );

      final updated = user.copyWith(isFavorite: true);
      expect(updated.isFavorite, isTrue);
      expect(updated.name, equals('Dave'));
    });

    test('Filter favorite contacts from a list of users', () {
      final users = [
        UserModel(id: '1', name: 'Alice', email: 'a@e.com', isFavorite: true),
        UserModel(id: '2', name: 'Bob', email: 'b@e.com', isFavorite: false),
        UserModel(id: '3', name: 'Charlie', email: 'c@e.com', isFavorite: true),
      ];

      final favorites = users.where((u) => u.isFavorite).toList();
      expect(favorites.length, equals(2));
      expect(favorites.map((u) => u.name), containsAll(['Alice', 'Charlie']));
    });
  });
}
