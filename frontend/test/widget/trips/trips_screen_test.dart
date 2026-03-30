import 'dart:async';

import 'package:expanse_tracker/features/auth/providers/auth_provider.dart';
import 'package:expanse_tracker/features/trips/models/trip_model.dart';
import 'package:expanse_tracker/features/trips/providers/trips_provider.dart';
import 'package:expanse_tracker/features/trips/screens/trips_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_repositories.dart';
import '../../helpers/test_data.dart';
import '../helpers/app_wrapper.dart';

void main() {
  Widget buildTrips({
    FakeTripRepository? tripRepo,
    FakeAuthRepository? authRepo,
  }) {
    final fakeAuth = authRepo ??
        (FakeAuthRepository()
          ..getMeShouldReturnNull = false
          ..userToReturn = kUserAdmin);
    final fakeTrips = tripRepo ?? FakeTripRepository();
    return buildTestApp(
      screen: const TripsScreen(),
      initialRoute: '/trips',
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        tripRepositoryProvider.overrideWithValue(fakeTrips),
      ],
    );
  }

  group('TripsScreen — layout', () {
    testWidgets('shows trip names after loading', (tester) async {
      await tester.pumpWidget(buildTrips());
      await tester.pumpAndSettle();

      expect(find.text('Paris Trip'), findsOneWidget);
      expect(find.text('Berlin'), findsOneWidget);
    });

    testWidgets('shows empty-state message when there are no trips',
        (tester) async {
      final emptyRepo = FakeTripRepository()..tripsToReturn = [];
      await tester.pumpWidget(buildTrips(tripRepo: emptyRepo));
      await tester.pumpAndSettle();

      expect(find.text('No trips yet'), findsOneWidget);
    });

    testWidgets('shows FAB for adding a trip', (tester) async {
      await tester.pumpWidget(buildTrips());
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('shows admin icon for admin users', (tester) async {
      await tester.pumpWidget(buildTrips());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.admin_panel_settings), findsOneWidget);
    });

    testWidgets('hides admin icon for non-admin users', (tester) async {
      final plainAuth = FakeAuthRepository()
        ..getMeShouldReturnNull = false
        ..userToReturn = kUserPlain;
      await tester.pumpWidget(buildTrips(authRepo: plainAuth));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.admin_panel_settings), findsNothing);
    });
  });

  group('TripsScreen — loading', () {
    testWidgets('shows CircularProgressIndicator during initial load',
        (tester) async {
      // A hanging repo keeps isLoading=true so the spinner stays visible.
      final hangingRepo = _HangingTripRepository();
      await tester.pumpWidget(buildTrips(tripRepo: hangingRepo));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

/// A trip repository whose [getTrips] never resolves, keeping
/// [TripsState.isLoading] true indefinitely for the loading test.
class _HangingTripRepository extends FakeTripRepository {
  @override
  Future<List<TripModel>> getTrips() => Completer<List<TripModel>>().future;
}
