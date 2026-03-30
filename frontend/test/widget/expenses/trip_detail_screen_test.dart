import 'dart:async';

import 'package:expanse_tracker/features/auth/providers/auth_provider.dart';
import 'package:expanse_tracker/features/expenses/providers/expenses_provider.dart';
import 'package:expanse_tracker/features/expenses/screens/trip_detail_screen.dart';
import 'package:expanse_tracker/features/trips/models/trip_model.dart';
import 'package:expanse_tracker/features/trips/providers/trips_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_repositories.dart';
import '../../helpers/test_data.dart';
import '../helpers/app_wrapper.dart';

void main() {
  Widget buildDetail({
    FakeExpenseRepository? expenseRepo,
    FakeTripRepository? tripRepo,
    FakeAuthRepository? authRepo,
  }) {
    final fakeAuth = authRepo ??
        (FakeAuthRepository()
          ..getMeShouldReturnNull = false
          ..userToReturn = kUserAdmin);
    final fakeTrips = tripRepo ??
        (FakeTripRepository()..tripsToReturn = [kTrip1]);
    final fakeExpenses = expenseRepo ?? FakeExpenseRepository();

    return buildTestApp(
      screen: TripDetailScreen(tripId: kTrip1.id, tripName: kTrip1.name),
      initialRoute: '/trips/10',
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        tripRepositoryProvider.overrideWithValue(fakeTrips),
        expenseRepositoryProvider.overrideWithValue(fakeExpenses),
      ],
    );
  }

  group('TripDetailScreen — participants', () {
    testWidgets('shows participant emails as chips', (tester) async {
      await tester.pumpWidget(buildDetail());
      await tester.pumpAndSettle();

      expect(find.text('admin@test.com'), findsWidgets);
      expect(find.text('user@test.com'), findsWidgets);
    });
  });

  group('TripDetailScreen — expenses', () {
    testWidgets('shows expense description', (tester) async {
      await tester.pumpWidget(buildDetail());
      await tester.pumpAndSettle();

      expect(find.text('Dinner'), findsOneWidget);
    });

    testWidgets('shows empty state when there are no expenses', (tester) async {
      final emptyExpenses = FakeExpenseRepository()
        ..expensesToReturn = []
        ..balancesToReturn = [];
      await tester.pumpWidget(buildDetail(expenseRepo: emptyExpenses));
      await tester.pumpAndSettle();

      expect(find.text('No expenses yet.'), findsOneWidget);
    });
  });

  group('TripDetailScreen — balances', () {
    testWidgets('shows balance emails', (tester) async {
      await tester.pumpWidget(buildDetail());
      await tester.pumpAndSettle();

      // Balance section lists user emails with net amounts.
      expect(find.textContaining('admin@test.com'), findsWidgets);
      expect(find.textContaining('user@test.com'), findsWidgets);
    });
  });

  group('TripDetailScreen — loading', () {
    testWidgets('shows LinearProgressIndicator while trips provider is loading',
        (tester) async {
      // A trip repo that never resolves keeps tripsState.isLoading=true,
      // which satisfies the isWorking condition in the AppBar.
      final hangingTrips = _HangingTripRepository();
      await tester.pumpWidget(buildDetail(tripRepo: hangingTrips));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}

/// A trip repository whose [getTrips] never resolves, keeping
/// [TripsState.isLoading] true indefinitely.
class _HangingTripRepository extends FakeTripRepository {
  @override
  Future<List<TripModel>> getTrips() => Completer<List<TripModel>>().future;
}
