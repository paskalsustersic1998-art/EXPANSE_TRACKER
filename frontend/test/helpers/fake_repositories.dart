import 'package:expanse_tracker/features/admin/repositories/admin_repository.dart';
import 'package:expanse_tracker/features/auth/models/user_model.dart';
import 'package:expanse_tracker/features/auth/repositories/auth_repository.dart';
import 'package:expanse_tracker/features/expenses/models/expense_model.dart';
import 'package:expanse_tracker/features/expenses/repositories/expense_repository.dart';
import 'package:expanse_tracker/features/trips/models/trip_model.dart';
import 'package:expanse_tracker/features/trips/repositories/trip_repository.dart';

import 'test_data.dart';

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

class FakeAuthRepository extends AuthRepository {
  bool shouldFail = false;
  bool getMeShouldReturnNull = false;
  UserModel userToReturn = kUserAdmin;

  @override
  Future<UserModel> register(String email, String password) async {
    if (shouldFail) throw Exception('Email already registered');
    return userToReturn;
  }

  @override
  Future<void> login(String email, String password) async {
    if (shouldFail) throw Exception('Invalid email or password');
  }

  @override
  Future<UserModel?> getMe() async {
    if (getMeShouldReturnNull) return null;
    return userToReturn;
  }

  @override
  Future<void> logout() async {}
}

// ---------------------------------------------------------------------------
// Trips
// ---------------------------------------------------------------------------

class FakeTripRepository extends TripRepository {
  bool shouldFail = false;
  String? failureMessage;
  List<TripModel> tripsToReturn = [kTrip1, kTrip2];
  TripModel tripToReturn = kTrip1;

  @override
  Future<List<TripModel>> getTrips() async {
    if (shouldFail) throw Exception(failureMessage ?? 'error');
    return tripsToReturn;
  }

  @override
  Future<TripModel> createTrip(String name, String? description) async {
    if (shouldFail) throw Exception(failureMessage ?? 'error');
    return TripModel(
      id: 99,
      name: name,
      description: description,
      createdBy: 1,
      createdAt: DateTime(2024, 8, 1),
      participants: [kParticipant1],
    );
  }

  @override
  Future<TripModel> getTrip(int id) async {
    if (shouldFail) throw Exception(failureMessage ?? 'error');
    return tripToReturn;
  }

  @override
  Future<TripModel> addParticipant(int tripId, String email) async {
    if (shouldFail) throw Exception(failureMessage ?? 'error');
    return TripModel(
      id: tripId,
      name: tripToReturn.name,
      description: tripToReturn.description,
      createdBy: tripToReturn.createdBy,
      createdAt: tripToReturn.createdAt,
      participants: [...tripToReturn.participants, kParticipant2],
    );
  }

  @override
  Future<void> deleteTrip(int tripId) async {
    if (shouldFail) throw Exception(failureMessage ?? 'error');
  }

  @override
  Future<TripModel> removeParticipant(int tripId, int participantId) async {
    if (shouldFail) throw Exception(failureMessage ?? 'error');
    return TripModel(
      id: tripId,
      name: tripToReturn.name,
      description: tripToReturn.description,
      createdBy: tripToReturn.createdBy,
      createdAt: tripToReturn.createdAt,
      participants: tripToReturn.participants
          .where((p) => p.id != participantId)
          .toList(),
    );
  }

  @override
  Future<TripModel> updateTrip(int tripId,
      {String? name, String? description}) async {
    if (shouldFail) throw Exception(failureMessage ?? 'error');
    return TripModel(
      id: tripId,
      name: name ?? tripToReturn.name,
      description: description ?? tripToReturn.description,
      createdBy: tripToReturn.createdBy,
      createdAt: tripToReturn.createdAt,
      participants: tripToReturn.participants,
    );
  }
}

// ---------------------------------------------------------------------------
// Expenses
// ---------------------------------------------------------------------------

class FakeExpenseRepository extends ExpenseRepository {
  bool shouldFail = false;
  List<BalanceEntry> balancesToReturn = [kBalance1, kBalance2];
  List<ExpenseModel> expensesToReturn = [kExpense1];
  List<Settlement> settlementsToReturn = [];
  Settlement settlementToReturn = kSettlement;

  @override
  Future<List<BalanceEntry>> getBalances(int tripId) async {
    if (shouldFail) throw Exception('error');
    return balancesToReturn;
  }

  @override
  Future<List<ExpenseModel>> listExpenses(int tripId) async {
    if (shouldFail) throw Exception('error');
    return expensesToReturn;
  }

  @override
  Future<List<Settlement>> listSettlements(int tripId) async {
    if (shouldFail) throw Exception('error');
    return settlementsToReturn;
  }

  @override
  Future<ExpenseModel> createExpense(
    int tripId,
    String description,
    double amount, {
    int? paidBy,
    required List<int> splitAmong,
  }) async {
    if (shouldFail) throw Exception('error');
    return kExpense1;
  }

  @override
  Future<void> deleteExpense(int tripId, int expenseId) async {
    if (shouldFail) throw Exception('error');
  }

  @override
  Future<void> settleExpense(int tripId, int expenseId) async {
    if (shouldFail) throw Exception('error');
  }

  @override
  Future<ExpenseModel> updateExpense(
    int tripId,
    int expenseId, {
    String? description,
    double? amount,
    int? paidBy,
    List<int>? splitAmong,
  }) async {
    if (shouldFail) throw Exception('error');
    return kExpense1;
  }

  @override
  Future<Settlement> settleUp(int tripId) async {
    if (shouldFail) throw Exception('error');
    return settlementToReturn;
  }
}

// ---------------------------------------------------------------------------
// Admin
// ---------------------------------------------------------------------------

class FakeAdminRepository extends AdminRepository {
  bool shouldFail = false;
  List<UserModel> usersToReturn = [kUserAdmin, kUserPlain];

  @override
  Future<List<UserModel>> getUsers() async {
    if (shouldFail) throw Exception('error');
    return usersToReturn;
  }

  @override
  Future<UserModel> updateUserRole(int userId, String role) async {
    if (shouldFail) throw Exception('error');
    final user = usersToReturn.firstWhere((u) => u.id == userId);
    return UserModel(
      id: user.id,
      email: user.email,
      role: role,
      isActive: user.isActive,
      createdAt: user.createdAt,
    );
  }
}
