import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense_model.dart';
import '../repositories/expense_repository.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (_) => ExpenseRepository(),
);

final expensesProvider =
    StateNotifierProvider.family<ExpensesNotifier, ExpensesState, int>(
  (ref, tripId) => ExpensesNotifier(ref.read(expenseRepositoryProvider), tripId),
);

class ExpensesState {
  final List<BalanceEntry> balances;
  final List<ExpenseModel> expenses;
  final List<Settlement> settlements;
  final bool isLoading;
  final String? error;

  const ExpensesState({
    this.balances = const [],
    this.expenses = const [],
    this.settlements = const [],
    this.isLoading = false,
    this.error,
  });

  ExpensesState copyWith({
    List<BalanceEntry>? balances,
    List<ExpenseModel>? expenses,
    List<Settlement>? settlements,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ExpensesState(
      balances: balances ?? this.balances,
      expenses: expenses ?? this.expenses,
      settlements: settlements ?? this.settlements,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ExpensesNotifier extends StateNotifier<ExpensesState> {
  ExpensesNotifier(this._repo, this._tripId) : super(const ExpensesState()) {
    _load();
  }

  final ExpenseRepository _repo;
  final int _tripId;

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _repo.getBalances(_tripId),
        _repo.listExpenses(_tripId),
        _repo.listSettlements(_tripId),
      ]);
      state = state.copyWith(
        balances: results[0] as List<BalanceEntry>,
        expenses: results[1] as List<ExpenseModel>,
        settlements: results[2] as List<Settlement>,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Failed to load trip data.');
    }
  }

  Future<bool> addExpense(
    String description,
    double amount, {
    int? paidBy,
    required List<int> splitAmong,
  }) async {
    try {
      await _repo.createExpense(_tripId, description, amount,
          paidBy: paidBy, splitAmong: splitAmong);
      await _load();
      return true;
    } catch (_) {
      state = state.copyWith(error: 'Failed to add expense.');
      return false;
    }
  }

  Future<bool> deleteExpense(int expenseId) async {
    try {
      await _repo.deleteExpense(_tripId, expenseId);
      await _load();
      return true;
    } catch (_) {
      state = state.copyWith(error: 'Failed to delete expense.');
      return false;
    }
  }

  Future<bool> settleExpense(int expenseId) async {
    try {
      await _repo.settleExpense(_tripId, expenseId);
      await _load();
      return true;
    } catch (_) {
      state = state.copyWith(error: 'Failed to settle expense.');
      return false;
    }
  }

  Future<bool> updateExpense(
    int expenseId, {
    String? description,
    double? amount,
    int? paidBy,
    List<int>? splitAmong,
  }) async {
    try {
      await _repo.updateExpense(
        _tripId,
        expenseId,
        description: description,
        amount: amount,
        paidBy: paidBy,
        splitAmong: splitAmong,
      );
      await _load();
      return true;
    } catch (_) {
      state = state.copyWith(error: 'Failed to update expense.');
      return false;
    }
  }

  Future<Settlement?> settleUp() async {
    try {
      final settlement = await _repo.settleUp(_tripId);
      await _load();
      return settlement;
    } catch (_) {
      state = state.copyWith(error: 'Failed to compute settlement.');
      return null;
    }
  }
}
