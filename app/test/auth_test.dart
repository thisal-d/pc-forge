import 'package:flutter_test/flutter_test.dart';
import 'package:pc_forge_mobile/core/auth_session.dart';
import 'package:pc_forge_mobile/features/auth/data/models/user_model.dart';

void main() {
  group('UserModel Tests', () {
    test('parses from JSON correctly with role and userId', () {
      final json = {
        'userId': 42,
        'email': 'test@pcforge.com',
        'firstName': 'John',
        'lastName': 'Doe',
        'role': 'Customer',
      };

      final user = UserModel.fromJson(json);
      expect(user.userId, 42);
      expect(user.email, 'test@pcforge.com');
      expect(user.firstName, 'John');
      expect(user.lastName, 'Doe');
      expect(user.roleName, 'Customer');
      expect(user.displayName, 'John Doe');
    });

    test('displayName falls back to email if names are null', () {
      final user = UserModel(userId: 1, email: 'user@pcforge.com');
      expect(user.displayName, 'user@pcforge.com');
    });
  });

  group('AuthSession Tests', () {
    setUp(() {
      AuthSession.instance.clearSession();
    });

    test('initial state is unauthenticated', () {
      expect(AuthSession.instance.isAuthenticated, false);
      expect(AuthSession.instance.currentUser, isNull);
      expect(AuthSession.instance.token, isNull);
    });

    test('setSession stores user and token', () {
      final user = UserModel(userId: 5, email: 'demo@pcforge.com');
      AuthSession.instance.setSession(user: user, token: 'mock_jwt_123');

      expect(AuthSession.instance.isAuthenticated, true);
      expect(AuthSession.instance.currentUser?.email, 'demo@pcforge.com');
      expect(AuthSession.instance.token, 'mock_jwt_123');
    });

    test('clearSession resets state', () {
      final user = UserModel(userId: 5, email: 'demo@pcforge.com');
      AuthSession.instance.setSession(user: user, token: 'mock_jwt_123');
      AuthSession.instance.clearSession();

      expect(AuthSession.instance.isAuthenticated, false);
      expect(AuthSession.instance.currentUser, isNull);
      expect(AuthSession.instance.token, isNull);
    });
  });
}
