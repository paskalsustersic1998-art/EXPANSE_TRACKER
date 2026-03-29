class BalanceEntry {
  final int userId;
  final String email;
  final double net; // positive = owed money, negative = owes money

  const BalanceEntry({
    required this.userId,
    required this.email,
    required this.net,
  });

  factory BalanceEntry.fromJson(Map<String, dynamic> json) {
    return BalanceEntry(
      userId: json['user_id'] as int,
      email: json['email'] as String,
      net: double.parse(json['net'].toString()),
    );
  }
}

class SettlementTransaction {
  final int id;
  final int fromUserId;
  final String fromEmail;
  final int toUserId;
  final String toEmail;
  final double amount;

  const SettlementTransaction({
    required this.id,
    required this.fromUserId,
    required this.fromEmail,
    required this.toUserId,
    required this.toEmail,
    required this.amount,
  });

  factory SettlementTransaction.fromJson(Map<String, dynamic> json) {
    return SettlementTransaction(
      id: json['id'] as int,
      fromUserId: json['from_user_id'] as int,
      fromEmail: json['from_email'] as String,
      toUserId: json['to_user_id'] as int,
      toEmail: json['to_email'] as String,
      amount: double.parse(json['amount'].toString()),
    );
  }
}

class Settlement {
  final int id;
  final int tripId;
  final int createdBy;
  final DateTime createdAt;
  final List<SettlementTransaction> transactions;

  const Settlement({
    required this.id,
    required this.tripId,
    required this.createdBy,
    required this.createdAt,
    required this.transactions,
  });

  factory Settlement.fromJson(Map<String, dynamic> json) {
    return Settlement(
      id: json['id'] as int,
      tripId: json['trip_id'] as int,
      createdBy: json['created_by'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      transactions: (json['transactions'] as List<dynamic>)
          .map((t) => SettlementTransaction.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SplitEntry {
  final int userId;
  final double share;

  const SplitEntry({required this.userId, required this.share});

  factory SplitEntry.fromJson(Map<String, dynamic> json) => SplitEntry(
        userId: json['user_id'] as int,
        share: double.parse(json['share'].toString()),
      );
}

class ExpenseModel {
  final int id;
  final int tripId;
  final int paidBy;
  final double amount;
  final String description;
  final bool isSettled;
  final DateTime createdAt;
  final List<SplitEntry> splits;

  const ExpenseModel({
    required this.id,
    required this.tripId,
    required this.paidBy,
    required this.amount,
    required this.description,
    required this.isSettled,
    required this.createdAt,
    required this.splits,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as int,
      tripId: json['trip_id'] as int,
      paidBy: json['paid_by'] as int,
      amount: double.parse(json['amount'].toString()),
      description: json['description'] as String,
      isSettled: json['is_settled'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      splits: (json['splits'] as List<dynamic>)
          .map((s) => SplitEntry.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}
