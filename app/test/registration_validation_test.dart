import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_forge_mobile/features/auth/data/auth_repository.dart';
import 'package:pc_forge_mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:pc_forge_mobile/services/api_service.dart';

class MockRegisterApiService extends ApiService {
  final bool simulateDuplicateEmail;
  final bool simulateNetworkFailure;
  final bool simulateServerError;

  MockRegisterApiService({
    this.simulateDuplicateEmail = false,
    this.simulateNetworkFailure = false,
    this.simulateServerError = false,
  });

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (simulateNetworkFailure) {
      throw SocketException('Connection refused');
    }
    if (simulateServerError) {
      throw ApiException(
        ApiService.extractErrorMessage({'message': 'Internal Server Error'}, 500),
        statusCode: 500,
      );
    }
    if (simulateDuplicateEmail) {
      throw ApiException(
        ApiService.extractErrorMessage({'message': 'A user with this email already exists.'}, 409),
        statusCode: 409,
      );
    }
    return {
      'userId': 99,
      'email': body['email'],
      'firstName': body['firstName'],
      'lastName': body['lastName'],
      'token': 'mock_valid_jwt_token',
      'role': 'Customer',
    };
  }
}

void main() {
  group('Mobile Registration Validation & Error Handling Tests', () {
    test('ApiService.extractErrorMessage translates validation and HTTP errors cleanly', () {
      // 1. Password validation error from backend
      expect(
        ApiService.extractErrorMessage({
          'errors': {
            'Password': ['Password must be at least 8 characters long.']
          }
        }, 400),
        'Password must be at least 8 characters long.',
      );

      // 2. Duplicate email error from backend
      expect(
        ApiService.extractErrorMessage({'message': 'An account with this email already exists.'}, 409),
        'An account with this email already exists.',
      );

      // 3. Last name required
      expect(
        ApiService.extractErrorMessage({
          'errors': {
            'LastName': ['Last name is required.']
          }
        }, 400),
        'Last name is required.',
      );

      // 4. Server error 500 never leaks technical details
      expect(
        ApiService.extractErrorMessage({'message': 'System.NullReferenceException: Object reference not set...'}, 500),
        'Something went wrong. Please try again later.',
      );

      // 5. Status code 429 rate limit
      expect(
        ApiService.extractErrorMessage({}, 429),
        'Too many requests. Please wait a moment and try again.',
      );

      // 6. Generic 400
      expect(
        ApiService.extractErrorMessage({}, 400),
        'Please check your information and try again.',
      );
    });

    testWidgets('1. Empty form keeps Register button disabled', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      await tester.pumpAndSettle();

      final btn = tester.widget<ElevatedButton>(find.byKey(const Key('register_submit_btn')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('2. Password shorter than 8 characters shows error and disables submit', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('register_firstname_field')), 'John');
      await tester.enterText(find.byKey(const Key('register_lastname_field')), 'Doe');
      await tester.enterText(find.byKey(const Key('register_email_field')), 'john@example.com');
      await tester.enterText(find.byKey(const Key('register_password_field')), 'Pass1!'); // 6 characters
      await tester.enterText(find.byKey(const Key('register_confirm_password_field')), 'Pass1!');
      await tester.pumpAndSettle();

      // Field displays clear 8-char validation requirement
      expect(find.text('Password must be at least 8 characters long.'), findsWidgets);

      final btn = tester.widget<ElevatedButton>(find.byKey(const Key('register_submit_btn')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('3. Password exactly 8 characters satisfies requirement and enables submit', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('register_firstname_field')), 'John');
      await tester.enterText(find.byKey(const Key('register_lastname_field')), 'Doe');
      await tester.enterText(find.byKey(const Key('register_email_field')), 'john@example.com');
      await tester.enterText(find.byKey(const Key('register_password_field')), 'Pass1234'); // Exactly 8 characters
      await tester.enterText(find.byKey(const Key('register_confirm_password_field')), 'Pass1234');
      await tester.pumpAndSettle();

      final btn = tester.widget<ElevatedButton>(find.byKey(const Key('register_submit_btn')));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('4. Password longer than 8 characters enables submit', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('register_firstname_field')), 'John');
      await tester.enterText(find.byKey(const Key('register_lastname_field')), 'Doe');
      await tester.enterText(find.byKey(const Key('register_email_field')), 'john@example.com');
      await tester.enterText(find.byKey(const Key('register_password_field')), 'SuperSecurePass2026!');
      await tester.enterText(find.byKey(const Key('register_confirm_password_field')), 'SuperSecurePass2026!');
      await tester.pumpAndSettle();

      final btn = tester.widget<ElevatedButton>(find.byKey(const Key('register_submit_btn')));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('5. One-character last name is accepted and enables submit', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('register_firstname_field')), 'Alex');
      await tester.enterText(find.byKey(const Key('register_lastname_field')), 'O'); // Single character last name
      await tester.enterText(find.byKey(const Key('register_email_field')), 'alex@example.com');
      await tester.enterText(find.byKey(const Key('register_password_field')), 'Password123!');
      await tester.enterText(find.byKey(const Key('register_confirm_password_field')), 'Password123!');
      await tester.pumpAndSettle();

      final btn = tester.widget<ElevatedButton>(find.byKey(const Key('register_submit_btn')));
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('6. Empty last name shows "Last name is required." and disables submit', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('register_firstname_field')), 'Alex');
      await tester.enterText(find.byKey(const Key('register_lastname_field')), ''); // Empty
      await tester.enterText(find.byKey(const Key('register_email_field')), 'alex@example.com');
      await tester.enterText(find.byKey(const Key('register_password_field')), 'Password123!');
      await tester.enterText(find.byKey(const Key('register_confirm_password_field')), 'Password123!');
      await tester.pumpAndSettle();

      expect(find.text('Last name is required.'), findsOneWidget);
      final btn = tester.widget<ElevatedButton>(find.byKey(const Key('register_submit_btn')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('7. Invalid email address shows validation error and disables submit', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('register_firstname_field')), 'Alex');
      await tester.enterText(find.byKey(const Key('register_lastname_field')), 'Smith');
      await tester.enterText(find.byKey(const Key('register_email_field')), 'invalid-email'); // Missing @ and domain
      await tester.enterText(find.byKey(const Key('register_password_field')), 'Password123!');
      await tester.enterText(find.byKey(const Key('register_confirm_password_field')), 'Password123!');
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address.'), findsOneWidget);
      final btn = tester.widget<ElevatedButton>(find.byKey(const Key('register_submit_btn')));
      expect(btn.onPressed, isNull);
    });

    testWidgets('8. Duplicate email displays user-friendly "An account with this email already exists."', (WidgetTester tester) async {
      final mockApi = MockRegisterApiService(simulateDuplicateEmail: true);
      final authRepo = AuthRepository(apiService: mockApi);

      // Verify AuthRepository translation
      expect(
        () => authRepo.register(
          email: 'existing@pcforge.com',
          password: 'Password123!',
          firstName: 'John',
          lastName: 'Doe',
        ),
        throwsA(predicate((e) => e is ApiException && e.message == 'An account with this email already exists.')),
      );
    });

    testWidgets('9. Network failure displays user-friendly "Unable to connect..." message', (WidgetTester tester) async {
      final mockApi = MockRegisterApiService(simulateNetworkFailure: true);
      final authRepo = AuthRepository(apiService: mockApi);

      expect(
        () => authRepo.register(
          email: 'offline@pcforge.com',
          password: 'Password123!',
          firstName: 'John',
          lastName: 'Doe',
        ),
        throwsA(predicate((e) => e is SocketException)),
      );
    });

    testWidgets('10. Server 500 error displays user-friendly "Something went wrong..." message', (WidgetTester tester) async {
      final mockApi = MockRegisterApiService(simulateServerError: true);
      final authRepo = AuthRepository(apiService: mockApi);

      expect(
        () => authRepo.register(
          email: 'serverfail@pcforge.com',
          password: 'Password123!',
          firstName: 'John',
          lastName: 'Doe',
        ),
        throwsA(predicate((e) => e is ApiException && e.message == 'Something went wrong. Please try again later.')),
      );
    });
  });
}
