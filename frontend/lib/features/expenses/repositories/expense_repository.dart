import 'package:dio/dio.dart';

import '../../../core/dio_client.dart';
import '../models/expense_model.dart';

class ExpenseRepository {
  final Dio _dio = DioClient.instance;

  Future<ExpenseModel> createExpense(
    int tripId,
    String description,
    double amount, {
    int? paidBy,
    required List<int> splitAmong,
  }) async {
    final response = await _dio.post(
      '/trips/$tripId/expenses',
      data: {
        'description': description,
        'amount': amount,
        'paid_by': paidBy,
        'split_among': splitAmong,
      },
    );
    return ExpenseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<BalanceEntry>> getBalances(int tripId) async {
    final response = await _dio.get('/trips/$tripId/balances');
    return (response.data as List<dynamic>)
        .map((e) => BalanceEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<ExpenseModel>> listExpenses(int tripId) async {
    final response = await _dio.get('/trips/$tripId/expenses');
    return (response.data as List<dynamic>)
        .map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteExpense(int tripId, int expenseId) async {
    await _dio.delete('/trips/$tripId/expenses/$expenseId');
  }

  Future<void> settleExpense(int tripId, int expenseId) async {
    await _dio.patch('/trips/$tripId/expenses/$expenseId/settle');
  }

  Future<ExpenseModel> updateExpense(
    int tripId,
    int expenseId, {
    String? description,
    double? amount,
    int? paidBy,
    List<int>? splitAmong,
  }) async {
    final response = await _dio.patch(
      '/trips/$tripId/expenses/$expenseId',
      data: {
        'description': description,
        'amount': amount,
        'paid_by': paidBy,
        'split_among': splitAmong,
      },
    );
    return ExpenseModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<Settlement>> listSettlements(int tripId) async {
    final response = await _dio.get('/trips/$tripId/settlements');
    return (response.data as List<dynamic>)
        .map((e) => Settlement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Settlement> settleUp(int tripId) async {
    final response = await _dio.post('/trips/$tripId/settlements');
    return Settlement.fromJson(response.data as Map<String, dynamic>);
  }
}
