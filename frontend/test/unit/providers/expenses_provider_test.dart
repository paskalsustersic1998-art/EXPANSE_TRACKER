import 'package:expanse_tracker/features/expenses/providers/expenses_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_repositories.dart';
import '../../helpers/test_data.dart';

ProviderContainer makeContainer(FakeExpenseRepository fakeRepo) {
  final container = ProviderContainer(
    overrides: [expenseRepositoryProvider.overrideWithValue(fakeRepo)],
  );
  addTearDown(container.dispose);
  return container;
}

/// Triggers a read to initialise the notifier and waits for _load() to finish.
Future<void> waitForInit(ProviderContainer container, {int tripId = 10}) async {
  // Access the notifier to ensure it's created
  container.read(expensesProvider(tripId).notifier);
  await Future.delayed(Duration.zero);
}

void main() {
  group('ExpensesNotifier — initialization (_load)', () {
    test('loads balances, expenses and settlements on creation', () async {
      final fakeRepo = FakeExpenseRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final state = container.read(expensesProvider(10));
      expect(state.balances.length, 2);
      expect(state.expenses.length, 1);
      expect(state.settlements, isEmpty);
      expect(state.isLoading, false);
      expect(state.error, isNull);
    });

    test('sets error when load fails', () async {
      final fakeRepo = FakeExpenseRepository()..shouldFail = true;
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final state = container.read(expensesProvider(10));
      expect(state.error, 'Failed to load trip data.');
      expect(state.balances, isEmpty);
      expect(state.expenses, isEmpty);
      expect(state.settlements, isEmpty);
    });

    test('two different tripId instances are independent', () async {
      final fakeRepo = FakeExpenseRepository();
      final container = makeContainer(fakeRepo);

      await waitForInit(container, tripId: 10);
      await waitForInit(container, tripId: 11);

      final state10 = container.read(expensesProvider(10));
      final state11 = container.read(expensesProvider(11));

      // Both load the same fake data but are separate state objects
      expect(state10.expenses.length, state11.expenses.length);

      // Mutating one does not affect the other
      fakeRepo.shouldFail = true;
      await container
          .read(expensesProvider(10).notifier)
          .deleteExpense(100);

      expect(container.read(expensesProvider(10)).error, isNotNull);
      // state11 error should still be null (was set before shouldFail = true)
      expect(container.read(expensesProvider(11)).error, isNull);
    });
  });

  group('ExpensesNotifier — addExpense', () {
    test('returns true and reloads state on success', () async {
      final fakeRepo = FakeExpenseRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result = await container
          .read(expensesProvider(10).notifier)
          .addExpense('Lunch', 40.0, splitAmong: [1, 2]);

      expect(result, true);
      expect(container.read(expensesProvider(10)).error, isNull);
      expect(container.read(expensesProvider(10)).isLoading, false);
    });

    test('returns false and sets error on failure', () async {
      final fakeRepo = FakeExpenseRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      fakeRepo.shouldFail = true;
      final result = await container
          .read(expensesProvider(10).notifier)
          .addExpense('Lunch', 40.0, splitAmong: [1, 2]);

      expect(result, false);
      expect(container.read(expensesProvider(10)).error, 'Failed to add expense.');
    });
  });

  group('ExpensesNotifier — deleteExpense', () {
    test('returns true and reloads state on success', () async {
      final fakeRepo = FakeExpenseRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result = await container
          .read(expensesProvider(10).notifier)
          .deleteExpense(100);

      expect(result, true);
      expect(container.read(expensesProvider(10)).isLoading, false);
    });

    test('returns false and sets error on failure', () async {
      final fakeRepo = FakeExpenseRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      fakeRepo.shouldFail = true;
      final result = await container
          .read(expensesProvider(10).notifier)
          .deleteExpense(100);

      expect(result, false);
      expect(container.read(expensesProvider(10)).error,
          'Failed to delete expense.');
    });
  });

  group('ExpensesNotifier — settleExpense', () {
    test('returns true on success', () async {
      final fakeRepo = FakeExpenseRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result = await container
          .read(expensesProvider(10).notifier)
          .settleExpense(100);

      expect(result, true);
    });

    test('returns false and sets error on failure', () async {
      final fakeRepo = FakeExpenseRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      fakeRepo.shouldFail = true;
      final result = await container
          .read(expensesProvider(10).notifier)
          .settleExpense(100);

      expect(result, false);
      expect(container.read(expensesProvider(10)).error,
          'Failed to settle expense.');
    });
  });

  group('ExpensesNotifier — updateExpense', () {
    test('returns true on success', () async {
      final fakeRepo = FakeExpenseRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result = await container
          .read(expensesProvider(10).notifier)
          .updateExpense(100, description: 'New desc', amount: 50.0);

      expect(result, true);
    });

    test('returns false and sets error on failure', () async {
      final fakeRepo = FakeExpenseRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      fakeRepo.shouldFail = true;
      final result = await container
          .read(expensesProvider(10).notifier)
          .updateExpense(100, amount: 50.0);

      expect(result, false);
      expect(container.read(expensesProvider(10)).error,
          'Failed to update expense.');
    });
  });

  group('ExpensesNotifier — settleUp', () {
    test('returns Settlement and reloads state on success', () async {
      final fakeRepo = FakeExpenseRepository()
        ..settlementToReturn = kSettlement;
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final settlement =
          await container.read(expensesProvider(10).notifier).settleUp();

      expect(settlement, isNotNull);
      expect(settlement!.id, kSettlement.id);
      expect(settlement.transactions.length, 1);
      expect(container.read(expensesProvider(10)).isLoading, false);
    });

    test('returns null and sets error on failure', () async {
      final fakeRepo = FakeExpenseRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      fakeRepo.shouldFail = true;
      final settlement =
          await container.read(expensesProvider(10).notifier).settleUp();

      expect(settlement, isNull);
      expect(container.read(expensesProvider(10)).error,
          'Failed to compute settlement.');
    });
  });

  group('ExpensesNotifier — state after reload', () {
    test('reflects updated data after successful mutation', () async {
      final fakeRepo = FakeExpenseRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      // Change what the fake returns before the reload triggered by mutation
      final newExpense = kExpense1;
      fakeRepo.expensesToReturn = [newExpense, newExpense]; // 2 now
      fakeRepo.balancesToReturn = [kBalance1]; // 1 balance now

      await container
          .read(expensesProvider(10).notifier)
          .addExpense('Another', 20.0, splitAmong: [1]);

      final state = container.read(expensesProvider(10));
      expect(state.expenses.length, 2);
      expect(state.balances.length, 1);
    });
  });
}
