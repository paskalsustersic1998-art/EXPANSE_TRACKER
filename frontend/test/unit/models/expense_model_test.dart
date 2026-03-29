import 'package:expanse_tracker/features/expenses/models/expense_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SplitEntry.fromJson', () {
    test('parses share as integer', () {
      final split = SplitEntry.fromJson({'user_id': 1, 'share': 30});
      expect(split.userId, 1);
      expect(split.share, 30.0);
    });

    test('parses share as decimal string', () {
      final split = SplitEntry.fromJson({'user_id': 2, 'share': '15.50'});
      expect(split.share, 15.50);
    });

    test('parses share as double', () {
      final split = SplitEntry.fromJson({'user_id': 3, 'share': 33.33});
      expect(split.share, closeTo(33.33, 0.001));
    });
  });

  group('ExpenseModel.fromJson', () {
    final baseJson = {
      'id': 100,
      'trip_id': 10,
      'paid_by': 1,
      'amount': '60.00',
      'description': 'Dinner',
      'is_settled': false,
      'created_at': '2024-06-02T00:00:00',
      'splits': [
        {'user_id': 1, 'share': '30.00'},
        {'user_id': 2, 'share': '30.00'},
      ],
    };

    test('parses all fields correctly', () {
      final expense = ExpenseModel.fromJson(baseJson);

      expect(expense.id, 100);
      expect(expense.tripId, 10);
      expect(expense.paidBy, 1);
      expect(expense.amount, 60.0);
      expect(expense.description, 'Dinner');
      expect(expense.isSettled, false);
      expect(expense.createdAt, DateTime.parse('2024-06-02T00:00:00'));
    });

    test('parses amount from string', () {
      final expense = ExpenseModel.fromJson({...baseJson, 'amount': '99.99'});
      expect(expense.amount, closeTo(99.99, 0.001));
    });

    test('parses amount from integer', () {
      final expense = ExpenseModel.fromJson({...baseJson, 'amount': 50});
      expect(expense.amount, 50.0);
    });

    test('parses is_settled true', () {
      final expense = ExpenseModel.fromJson({...baseJson, 'is_settled': true});
      expect(expense.isSettled, true);
    });

    test('parses splits list', () {
      final expense = ExpenseModel.fromJson(baseJson);
      expect(expense.splits.length, 2);
      expect(expense.splits[0].userId, 1);
      expect(expense.splits[0].share, 30.0);
    });

    test('parses empty splits list', () {
      final expense = ExpenseModel.fromJson({...baseJson, 'splits': []});
      expect(expense.splits, isEmpty);
    });
  });

  group('BalanceEntry.fromJson', () {
    test('parses positive net balance', () {
      final b = BalanceEntry.fromJson({
        'user_id': 1,
        'email': 'a@b.com',
        'net': '30.00',
      });
      expect(b.net, 30.0);
      expect(b.net.isNegative, false);
    });

    test('parses negative net balance', () {
      final b = BalanceEntry.fromJson({
        'user_id': 2,
        'email': 'c@d.com',
        'net': '-30.00',
      });
      expect(b.net, -30.0);
      expect(b.net.isNegative, true);
    });

    test('parses zero net balance', () {
      final b = BalanceEntry.fromJson({
        'user_id': 3,
        'email': 'e@f.com',
        'net': '0.00',
      });
      expect(b.net, 0.0);
    });
  });

  group('SettlementTransaction.fromJson', () {
    test('parses all fields correctly', () {
      final t = SettlementTransaction.fromJson({
        'id': 1,
        'from_user_id': 2,
        'from_email': 'debtor@test.com',
        'to_user_id': 1,
        'to_email': 'creditor@test.com',
        'amount': '30.00',
      });

      expect(t.id, 1);
      expect(t.fromUserId, 2);
      expect(t.fromEmail, 'debtor@test.com');
      expect(t.toUserId, 1);
      expect(t.toEmail, 'creditor@test.com');
      expect(t.amount, 30.0);
    });
  });

  group('Settlement.fromJson', () {
    test('parses nested transactions list', () {
      final s = Settlement.fromJson({
        'id': 1,
        'trip_id': 10,
        'created_by': 1,
        'created_at': '2024-06-10T00:00:00',
        'transactions': [
          {
            'id': 1,
            'from_user_id': 2,
            'from_email': 'b@test.com',
            'to_user_id': 1,
            'to_email': 'a@test.com',
            'amount': '30.00',
          },
        ],
      });

      expect(s.id, 1);
      expect(s.tripId, 10);
      expect(s.transactions.length, 1);
      expect(s.transactions[0].amount, 30.0);
    });

    test('parses empty transactions list', () {
      final s = Settlement.fromJson({
        'id': 2,
        'trip_id': 10,
        'created_by': 1,
        'created_at': '2024-06-11T00:00:00',
        'transactions': [],
      });
      expect(s.transactions, isEmpty);
    });
  });
}
