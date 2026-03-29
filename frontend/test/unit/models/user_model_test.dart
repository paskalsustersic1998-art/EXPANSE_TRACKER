import 'package:expanse_tracker/features/auth/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel.fromJson', () {
    final baseJson = {
      'id': 1,
      'email': 'test@example.com',
      'role': 'user',
      'is_active': true,
      'created_at': '2024-01-15T10:30:00',
    };

    test('parses all fields correctly', () {
      final user = UserModel.fromJson(baseJson);

      expect(user.id, 1);
      expect(user.email, 'test@example.com');
      expect(user.role, 'user');
      expect(user.isActive, true);
      expect(user.createdAt, DateTime.parse('2024-01-15T10:30:00'));
    });

    test('parses admin role', () {
      final user = UserModel.fromJson({...baseJson, 'role': 'admin'});
      expect(user.role, 'admin');
    });

    test('parses is_active false', () {
      final user = UserModel.fromJson({...baseJson, 'is_active': false});
      expect(user.isActive, false);
    });

    test('parses created_at ISO string into DateTime', () {
      final user = UserModel.fromJson({
        ...baseJson,
        'created_at': '2023-06-01T00:00:00.000Z',
      });
      expect(user.createdAt.year, 2023);
      expect(user.createdAt.month, 6);
      expect(user.createdAt.day, 1);
    });

    test('different user ids are distinct', () {
      final user1 = UserModel.fromJson({...baseJson, 'id': 1});
      final user2 = UserModel.fromJson({...baseJson, 'id': 2});
      expect(user1.id, isNot(user2.id));
    });
  });
}
