import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pc_forge_mobile/main.dart';

void main() {
  testWidgets('PCForge smoke test renders initial login screen with basic UI elements', (WidgetTester tester) async {
    await tester.pumpWidget(const PCForgeApp());

    expect(find.text('Login'), findsWidgets);
    expect(find.text('PCForge Mobile'), findsOneWidget);
    expect(find.text('Sign in with your customer account'), findsOneWidget);
    expect(find.byKey(const Key('login_email_field')), findsOneWidget);
    expect(find.byKey(const Key('login_password_field')), findsOneWidget);
    expect(find.byKey(const Key('login_submit_btn')), findsOneWidget);
    expect(find.byKey(const Key('login_quick_fill_btn')), findsOneWidget);
    expect(find.byKey(const Key('login_to_register_btn')), findsOneWidget);
  });

  testWidgets('Login form displays validation errors on empty submission', (WidgetTester tester) async {
    await tester.pumpWidget(const PCForgeApp());

    // Tap the sign in button without entering any input
    await tester.tap(find.byKey(const Key('login_submit_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
  });

  testWidgets('Quick Fill button populates customer credentials on Login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PCForgeApp());

    await tester.tap(find.byKey(const Key('login_quick_fill_btn')));
    await tester.pumpAndSettle();

    expect(find.text('customer@pcforge.com'), findsOneWidget);
  });

  testWidgets('Entering customer credentials populates text fields on Login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PCForgeApp());

    await tester.enterText(find.byKey(const Key('login_email_field')), 'customer@pcforge.com');
    await tester.enterText(find.byKey(const Key('login_password_field')), 'Cust123!');
    await tester.pumpAndSettle();

    expect(find.text('customer@pcforge.com'), findsOneWidget);
  });

  testWidgets('Navigates to Register screen and verifies basic registration UI', (WidgetTester tester) async {
    await tester.pumpWidget(const PCForgeApp());

    // Tap Register link
    await tester.tap(find.byKey(const Key('login_to_register_btn')));
    await tester.pumpAndSettle();

    // Verify Register screen elements
    expect(find.text('Create Account'), findsWidgets);
    expect(find.text('Join PCForge'), findsOneWidget);
    expect(find.byKey(const Key('register_firstname_field')), findsOneWidget);
    expect(find.byKey(const Key('register_lastname_field')), findsOneWidget);
    expect(find.byKey(const Key('register_email_field')), findsOneWidget);
    expect(find.byKey(const Key('register_password_field')), findsOneWidget);
    expect(find.byKey(const Key('register_confirm_password_field')), findsOneWidget);
    expect(find.byKey(const Key('register_submit_btn')), findsOneWidget);

    // Verify Register button is initially disabled when form is empty
    ElevatedButton submitBtn = tester.widget<ElevatedButton>(find.byKey(const Key('register_submit_btn')));
    expect(submitBtn.onPressed, isNull);

    // Enter partial data: invalid 3-char password
    await tester.enterText(find.byKey(const Key('register_firstname_field')), 'John');
    await tester.enterText(find.byKey(const Key('register_lastname_field')), 'D'); // Single char last name
    await tester.enterText(find.byKey(const Key('register_email_field')), 'test@pcforge.com');
    await tester.enterText(find.byKey(const Key('register_password_field')), '123456');
    await tester.enterText(find.byKey(const Key('register_confirm_password_field')), '123456');
    await tester.pumpAndSettle();

    // 6 chars is less than 8 - shows validation error and button remains disabled
    expect(find.text('Password must be at least 8 characters long.'), findsWidgets);
    submitBtn = tester.widget<ElevatedButton>(find.byKey(const Key('register_submit_btn')));
    expect(submitBtn.onPressed, isNull);

    // Enter valid 8-character password and confirm password
    await tester.enterText(find.byKey(const Key('register_password_field')), 'Password123!');
    await tester.enterText(find.byKey(const Key('register_confirm_password_field')), 'Password123!');
    await tester.pumpAndSettle();

    // With single-char last name ('D') and >= 8 char password, button is enabled!
    submitBtn = tester.widget<ElevatedButton>(find.byKey(const Key('register_submit_btn')));
    expect(submitBtn.onPressed, isNotNull);

    // Clearing last name disables button again
    await tester.enterText(find.byKey(const Key('register_lastname_field')), '');
    await tester.pumpAndSettle();
    expect(find.text('Last name is required.'), findsOneWidget);
    submitBtn = tester.widget<ElevatedButton>(find.byKey(const Key('register_submit_btn')));
    expect(submitBtn.onPressed, isNull);

    // Navigate back to Login screen
    final loginBtn = find.byKey(const Key('register_to_login_btn'));
    await tester.scrollUntilVisible(loginBtn, 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(loginBtn);
    await tester.pumpAndSettle();

    expect(find.text('Sign in with your customer account'), findsOneWidget);
  });
}
