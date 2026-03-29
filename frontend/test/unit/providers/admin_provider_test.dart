import 'package:expanse_tracker/features/admin/providers/admin_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_repositories.dart';
import '../../helpers/test_data.dart';

ProviderContainer makeContainer(FakeAdminRepository fakeRepo) {
  final container = ProviderContainer(
    overrides: [adminRepositoryProvider.overrideWithValue(fakeRepo)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> waitForInit(ProviderContainer container) async {
  await container.read(adminProvider.notifier).loadUsers();
}

void main() {
  group('AdminNotifier — loadUsers', () {
    test('populates users list on success', () async {
      final fakeRepo = FakeAdminRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final state = container.read(adminProvider);
      expect(state.users.length, 2);
      expect(state.users[0].email, kUserAdmin.email);
      expect(state.users[1].email, kUserPlain.email);
      expect(state.isLoading, false);
      expect(state.error, isNull);
    });

    test('sets error on failure', () async {
      final fakeRepo = FakeAdminRepository()..shouldFail = true;
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final state = container.read(adminProvider);
      expect(state.users, isEmpty);
      expect(state.error, 'Failed to load users.');
      expect(state.isLoading, false);
    });

    test('clears error on successful reload', () async {
      final fakeRepo = FakeAdminRepository()..shouldFail = true;
      final container = makeContainer(fakeRepo);
      await waitForInit(container);
      expect(container.read(adminProvider).error, isNotNull);

      fakeRepo.shouldFail = false;
      await container.read(adminProvider.notifier).loadUsers();

      expect(container.read(adminProvider).error, isNull);
      expect(container.read(adminProvider).users, isNotEmpty);
    });
  });

  group('AdminNotifier — updateRole', () {
    test('returns true and updates only the targeted user', () async {
      final fakeRepo = FakeAdminRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result =
          await container.read(adminProvider.notifier).updateRole(2, 'admin');

      expect(result, true);
      final state = container.read(adminProvider);
      // User with id 2 is now admin
      final updated = state.users.firstWhere((u) => u.id == 2);
      expect(updated.role, 'admin');
      // User with id 1 is unchanged
      final unchanged = state.users.firstWhere((u) => u.id == 1);
      expect(unchanged.role, kUserAdmin.role);
    });

    test('returns false and keeps users list unchanged on failure', () async {
      final fakeRepo = FakeAdminRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);
      final originalRoles =
          container.read(adminProvider).users.map((u) => u.role).toList();

      fakeRepo.shouldFail = true;
      final result =
          await container.read(adminProvider.notifier).updateRole(2, 'admin');

      expect(result, false);
      expect(container.read(adminProvider).error, 'Failed to update role.');
      final currentRoles =
          container.read(adminProvider).users.map((u) => u.role).toList();
      expect(currentRoles, originalRoles);
    });

    test('only replaces the targeted user in the list', () async {
      final fakeRepo = FakeAdminRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      await container.read(adminProvider.notifier).updateRole(2, 'admin');

      final users = container.read(adminProvider).users;
      // List length unchanged
      expect(users.length, 2);
      // User 1 still has original data
      expect(users.firstWhere((u) => u.id == 1).email, kUserAdmin.email);
    });

    test('transitions isLoading during loadUsers', () async {
      final fakeRepo = FakeAdminRepository();
      final container = makeContainer(fakeRepo);

      final states = <AdminState>[];
      container.listen(adminProvider, (_, next) => states.add(next));

      await container.read(adminProvider.notifier).loadUsers();

      expect(states.first.isLoading, true);
      expect(states.last.isLoading, false);
    });
  });
}
