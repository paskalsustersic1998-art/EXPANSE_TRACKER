import 'dart:async';

import 'package:expanse_tracker/features/auth/models/user_model.dart';
import 'package:expanse_tracker/features/auth/providers/auth_provider.dart';
import 'package:expanse_tracker/features/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_repositories.dart';
import '../helpers/app_wrapper.dart';

void main() {
  Widget buildLogin({FakeAuthRepository? repo}) {
    final fakeRepo = repo ?? (FakeAuthRepository()..getMeShouldReturnNull = true);
    return buildTestApp(
      screen: const LoginScreen(),
      initialRoute: '/login',
      overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
    );
  }

  group('LoginScreen — layout', () {
    testWidgets('renders email field, password field, and sign-in button',
        (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
    });

    testWidgets('renders register link', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pumpAndSettle();

      expect(find.textContaining("Don't have an account"), findsOneWidget);
    });
  });

  group('LoginScreen — validation', () {
    testWidgets('shows error for invalid email format', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'notanemail');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('accepts valid email', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'user@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsNothing);
    });

    testWidgets('rejects email without domain (test@)', (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'test@');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('shows error for password shorter than 6 characters',
        (tester) async {
      await tester.pumpWidget(buildLogin());
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'user@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), '123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Min 6 characters'), findsOneWidget);
    });
  });

  group('LoginScreen — state', () {
    testWidgets('shows CircularProgressIndicator while loading', (tester) async {
      // Don't call getMeShouldReturnNull=true — the session restore is async,
      // so the widget starts in loading state before getMe resolves.
      final hangingRepo = _HangingAuthRepository();
      await tester.pumpWidget(buildLogin(repo: hangingRepo));
      // One pump without settling: widget is still loading.
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays error message from auth state', (tester) async {
      final fakeRepo = FakeAuthRepository()
        ..shouldFail = true
        ..getMeShouldReturnNull = true;
      await tester.pumpWidget(buildLogin(repo: fakeRepo));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'user@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'wrongpass');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid email or password.'), findsOneWidget);
    });
  });
}

/// A repository whose getMe() never resolves, keeping the notifier in the
/// loading state indefinitely so the loading UI can be tested synchronously.
class _HangingAuthRepository extends FakeAuthRepository {
  @override
  Future<UserModel?> getMe() => Completer<UserModel?>().future; // never completes
}
