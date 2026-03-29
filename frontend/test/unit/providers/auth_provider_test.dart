import 'package:expanse_tracker/features/auth/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_repositories.dart';
import '../../helpers/test_data.dart';

ProviderContainer makeContainer(FakeAuthRepository fakeRepo) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
  );
  addTearDown(container.dispose);
  return container;
}

/// Forces [authProvider] to initialize and waits for _restoreSession to finish.
Future<void> waitForInit(ProviderContainer container) async {
  container.read(authProvider); // trigger creation + _restoreSession
  await Future.delayed(Duration.zero); // let the async init complete
}

void main() {
  group('AuthNotifier — initialization', () {
    test('restores session when getMe returns a user', () async {
      final fakeRepo = FakeAuthRepository()..userToReturn = kUserAdmin;
      final container = makeContainer(fakeRepo);

      await waitForInit(container);

      final state = container.read(authProvider);
      expect(state.isAuthenticated, true);
      expect(state.user?.email, kUserAdmin.email);
      expect(state.isLoading, false);
      expect(state.error, isNull);
    });

    test('stays unauthenticated when getMe returns null', () async {
      final fakeRepo = FakeAuthRepository()..getMeShouldReturnNull = true;
      final container = makeContainer(fakeRepo);

      await waitForInit(container);

      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.user, isNull);
      expect(state.isLoading, false);
    });
  });

  group('AuthNotifier — login', () {
    test('returns true and sets user on success', () async {
      final fakeRepo = FakeAuthRepository()..userToReturn = kUserPlain;
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result =
          await container.read(authProvider.notifier).login('a@b.com', 'pass123');

      expect(result, true);
      final state = container.read(authProvider);
      expect(state.isAuthenticated, true);
      expect(state.user?.email, kUserPlain.email);
      expect(state.error, isNull);
      expect(state.isLoading, false);
    });

    test('returns false and sets error on wrong credentials', () async {
      final fakeRepo = FakeAuthRepository()..shouldFail = true;
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result = await container
          .read(authProvider.notifier)
          .login('a@b.com', 'wrongpass');

      expect(result, false);
      final state = container.read(authProvider);
      expect(state.isAuthenticated, false);
      expect(state.error, 'Invalid email or password.');
      expect(state.isLoading, false);
    });

    test('sets network error message on SocketException', () async {
      final fakeRepo = FakeAuthRepository();
      fakeRepo.shouldFail = false;

      // Override login to throw a SocketException-like message
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((_) => _SocketFailAuthRepo()),
        ],
      );
      addTearDown(container.dispose);
      await waitForInit(container);

      await container
          .read(authProvider.notifier)
          .login('a@b.com', 'pass123');

      expect(container.read(authProvider).error,
          'Cannot reach server. Is the backend running?');
    });

    test('sets generic error message on unexpected exception', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWith((_) => _GenericFailAuthRepo()),
        ],
      );
      addTearDown(container.dispose);
      await waitForInit(container);

      await container
          .read(authProvider.notifier)
          .login('a@b.com', 'pass123');

      expect(container.read(authProvider).error,
          'Something went wrong. Please try again.');
    });

    test('transitions isLoading true then false', () async {
      final fakeRepo = FakeAuthRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final states = <AuthState>[];
      container.listen(authProvider, (_, next) => states.add(next));

      await container
          .read(authProvider.notifier)
          .login('a@b.com', 'pass123');

      expect(states.first.isLoading, true);
      expect(states.last.isLoading, false);
    });

    test('clears previous error on new login attempt', () async {
      final fakeRepo = FakeAuthRepository()..shouldFail = true;
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      // First login fails → sets error
      await container
          .read(authProvider.notifier)
          .login('a@b.com', 'bad');
      expect(container.read(authProvider).error, isNotNull);

      // Second login succeeds → error cleared
      fakeRepo.shouldFail = false;
      await container
          .read(authProvider.notifier)
          .login('a@b.com', 'good');
      expect(container.read(authProvider).error, isNull);
    });
  });

  group('AuthNotifier — register', () {
    test('returns true and authenticates on success', () async {
      final fakeRepo = FakeAuthRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result = await container
          .read(authProvider.notifier)
          .register('new@b.com', 'pass123');

      expect(result, true);
      expect(container.read(authProvider).isAuthenticated, true);
    });

    test('returns false and sets error when email taken', () async {
      final fakeRepo = FakeAuthRepository()..shouldFail = true;
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result = await container
          .read(authProvider.notifier)
          .register('taken@b.com', 'pass123');

      expect(result, false);
      expect(container.read(authProvider).error, 'Email already registered.');
    });
  });

  group('AuthNotifier — logout', () {
    test('clears user, loading, and error', () async {
      final fakeRepo = FakeAuthRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      // Confirm logged in first
      expect(container.read(authProvider).isAuthenticated, true);

      await container.read(authProvider.notifier).logout();

      final state = container.read(authProvider);
      expect(state.user, isNull);
      expect(state.isLoading, false);
      expect(state.error, isNull);
      expect(state.isAuthenticated, false);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers for specific error scenarios
// ---------------------------------------------------------------------------

class _SocketFailAuthRepo extends FakeAuthRepository {
  @override
  Future<void> login(String email, String password) async {
    throw Exception('SocketException: Connection refused');
  }
}

class _GenericFailAuthRepo extends FakeAuthRepository {
  @override
  Future<void> login(String email, String password) async {
    throw Exception('Something totally unexpected');
  }
}
