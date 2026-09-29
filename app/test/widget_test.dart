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

    // Verify validation errors on empty submission in Register screen
    await tester.tap(find.byKey(const Key('register_submit_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter an email'), findsOneWidget);
    expect(find.text('Please enter a password'), findsOneWidget);
    expect(find.text('Please confirm your password'), findsOneWidget);

    // Test password length and mismatch validation
    await tester.enterText(find.byKey(const Key('register_email_field')), 'test@pcforge.com');
    await tester.enterText(find.byKey(const Key('register_password_field')), '123');
    await tester.enterText(find.byKey(const Key('register_confirm_password_field')), '456');
    await tester.tap(find.byKey(const Key('register_submit_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Password must be at least 6 characters'), findsOneWidget);

    // Navigate back to Login screen
    final loginBtn = find.byKey(const Key('register_to_login_btn'));
    await tester.scrollUntilVisible(loginBtn, 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(loginBtn);
    await tester.pumpAndSettle();

    expect(find.text('Sign in with your customer account'), findsOneWidget);
  });
}
