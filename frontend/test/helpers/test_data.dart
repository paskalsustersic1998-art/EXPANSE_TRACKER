import 'package:expanse_tracker/features/auth/models/user_model.dart';
import 'package:expanse_tracker/features/expenses/models/expense_model.dart';
import 'package:expanse_tracker/features/trips/models/trip_model.dart';

final kUserAdmin = UserModel(
  id: 1,
  email: 'admin@test.com',
  role: 'admin',
  isActive: true,
  createdAt: DateTime(2024, 1, 1),
);

final kUserPlain = UserModel(
  id: 2,
  email: 'user@test.com',
  role: 'user',
  isActive: true,
  createdAt: DateTime(2024, 2, 1),
);

final kParticipant1 = ParticipantModel(id: 1, email: 'admin@test.com');
final kParticipant2 = ParticipantModel(id: 2, email: 'user@test.com');

final kTrip1 = TripModel(
  id: 10,
  name: 'Paris Trip',
  description: 'Fun times',
  createdBy: 1,
  createdAt: DateTime(2024, 6, 1),
  participants: [kParticipant1, kParticipant2],
);

final kTrip2 = TripModel(
  id: 11,
  name: 'Berlin',
  description: null,
  createdBy: 2,
  createdAt: DateTime(2024, 7, 1),
  participants: [],
);

final kSplit1 = SplitEntry(userId: 1, share: 30.0);
final kSplit2 = SplitEntry(userId: 2, share: 30.0);

final kExpense1 = ExpenseModel(
  id: 100,
  tripId: 10,
  paidBy: 1,
  amount: 60.0,
  description: 'Dinner',
  isSettled: false,
  createdAt: DateTime(2024, 6, 2),
  splits: [kSplit1, kSplit2],
);

final kBalance1 = BalanceEntry(userId: 1, email: 'admin@test.com', net: 30.0);
final kBalance2 = BalanceEntry(userId: 2, email: 'user@test.com', net: -30.0);

final kSettlementTransaction = SettlementTransaction(
  id: 1,
  fromUserId: 2,
  fromEmail: 'user@test.com',
  toUserId: 1,
  toEmail: 'admin@test.com',
  amount: 30.0,
);

final kSettlement = Settlement(
  id: 1,
  tripId: 10,
  createdBy: 1,
  createdAt: DateTime(2024, 6, 10),
  transactions: [kSettlementTransaction],
);
