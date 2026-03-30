import 'package:expanse_tracker/features/auth/providers/auth_provider.dart';
import 'package:expanse_tracker/features/auth/screens/register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_repositories.dart';
import '../helpers/app_wrapper.dart';

void main() {
  Widget buildRegister({FakeAuthRepository? repo}) {
    final fakeRepo = repo ?? (FakeAuthRepository()..getMeShouldReturnNull = true);
    return buildTestApp(
      screen: const RegisterScreen(),
      initialRoute: '/register',
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
    );
  }

  group('RegisterScreen — layout', () {
    testWidgets('renders email field, password field, and register button',
        (tester) async {
      await tester.pumpWidget(buildRegister());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Register'), findsOneWidget);
    });

    testWidgets('renders sign-in link', (tester) async {
      await tester.pumpWidget(buildRegister());
      await tester.pumpAndSettle();

      expect(find.textContaining('Already have an account'), findsOneWidget);
    });
  });

  group('RegisterScreen — validation', () {
    testWidgets('shows error for invalid email format', (tester) async {
      await tester.pumpWidget(buildRegister());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'bademail');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Register'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('rejects email without domain (test@)', (tester) async {
      await tester.pumpWidget(buildRegister());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'test@');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Register'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('shows error for password shorter than 6 characters',
        (tester) async {
      await tester.pumpWidget(buildRegister());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'user@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), '123');
      await tester.tap(find.widgetWithText(FilledButton, 'Register'));
      await tester.pump();

      expect(find.text('Min 6 characters'), findsOneWidget);
    });
  });

  group('RegisterScreen — state', () {
    testWidgets('displays error message when email is already taken',
        (tester) async {
      final fakeRepo = FakeAuthRepository()
        ..shouldFail = true
        ..getMeShouldReturnNull = true;
      await tester.pumpWidget(buildRegister(repo: fakeRepo));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'taken@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Register'));
      await tester.pumpAndSettle();

      expect(find.text('Email already registered.'), findsOneWidget);
    });
  });
}
