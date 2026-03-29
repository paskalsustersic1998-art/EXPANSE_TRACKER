import 'package:expanse_tracker/features/trips/providers/trips_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_repositories.dart';
import '../../helpers/test_data.dart';

ProviderContainer makeContainer(FakeTripRepository fakeRepo) {
  final container = ProviderContainer(
    overrides: [tripRepositoryProvider.overrideWithValue(fakeRepo)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> waitForInit(ProviderContainer container) async {
  await container.read(tripsProvider.notifier).loadTrips();
}

void main() {
  group('TripsNotifier — loadTrips', () {
    test('populates trips list on success', () async {
      final fakeRepo = FakeTripRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final state = container.read(tripsProvider);
      expect(state.trips.length, 2);
      expect(state.trips[0].name, kTrip1.name);
      expect(state.trips[1].name, kTrip2.name);
      expect(state.isLoading, false);
      expect(state.error, isNull);
    });

    test('sets error and empty list on failure', () async {
      final fakeRepo = FakeTripRepository()..shouldFail = true;
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final state = container.read(tripsProvider);
      expect(state.trips, isEmpty);
      expect(state.error, 'Failed to load trips.');
      expect(state.isLoading, false);
    });

    test('clears previous error on successful reload', () async {
      final fakeRepo = FakeTripRepository()..shouldFail = true;
      final container = makeContainer(fakeRepo);
      await waitForInit(container);
      expect(container.read(tripsProvider).error, isNotNull);

      fakeRepo.shouldFail = false;
      await container.read(tripsProvider.notifier).loadTrips();

      expect(container.read(tripsProvider).error, isNull);
    });

    test('transitions isLoading true then false', () async {
      final fakeRepo = FakeTripRepository();
      final container = makeContainer(fakeRepo);

      final states = <TripsState>[];
      container.listen(tripsProvider, (_, next) => states.add(next));

      await container.read(tripsProvider.notifier).loadTrips();

      expect(states.first.isLoading, true);
      expect(states.last.isLoading, false);
    });
  });

  group('TripsNotifier — createTrip', () {
    test('returns true and prepends new trip to list', () async {
      final fakeRepo = FakeTripRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result = await container
          .read(tripsProvider.notifier)
          .createTrip('Tokyo', 'Cherry blossoms');

      expect(result, true);
      final trips = container.read(tripsProvider).trips;
      expect(trips.length, 3);
      expect(trips.first.name, 'Tokyo');
    });

    test('returns false and sets error on failure', () async {
      final fakeRepo = FakeTripRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      fakeRepo.shouldFail = true;
      final result = await container
          .read(tripsProvider.notifier)
          .createTrip('Tokyo', null);

      expect(result, false);
      expect(container.read(tripsProvider).error, 'Failed to create trip.');
      expect(container.read(tripsProvider).trips.length, 2);
    });

    test('creates trip without description', () async {
      final fakeRepo = FakeTripRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result = await container
          .read(tripsProvider.notifier)
          .createTrip('Solo Trip', null);

      expect(result, true);
      expect(container.read(tripsProvider).trips.first.name, 'Solo Trip');
    });
  });

  group('TripsNotifier — deleteTrip', () {
    test('returns true and removes trip from list', () async {
      final fakeRepo = FakeTripRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result =
          await container.read(tripsProvider.notifier).deleteTrip(kTrip1.id);

      expect(result, true);
      final trips = container.read(tripsProvider).trips;
      expect(trips.length, 1);
      expect(trips.any((t) => t.id == kTrip1.id), false);
    });

    test('sets specific message when error contains "unsettled"', () async {
      final fakeRepo = FakeTripRepository()
        ..shouldFail = true
        ..failureMessage = 'Trip has unsettled expenses';
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      await container.read(tripsProvider.notifier).deleteTrip(kTrip1.id);

      expect(container.read(tripsProvider).error,
          'Settle expenses before deleting this trip.');
    });

    test('sets generic message when error does not contain "unsettled"', () async {
      final fakeRepo = FakeTripRepository()
        ..shouldFail = true
        ..failureMessage = 'network error';
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      await container.read(tripsProvider.notifier).deleteTrip(kTrip1.id);

      expect(container.read(tripsProvider).error, 'Failed to delete trip.');
    });

    test('keeps trips list unchanged on failure', () async {
      final fakeRepo = FakeTripRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container); // loads 2 trips successfully

      fakeRepo.shouldFail = true; // now fail the delete
      await container.read(tripsProvider.notifier).deleteTrip(kTrip1.id);

      expect(container.read(tripsProvider).trips.length, 2);
    });
  });

  group('TripsNotifier — addParticipant', () {
    test('returns true and updates trip in list', () async {
      final fakeRepo = FakeTripRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result = await container
          .read(tripsProvider.notifier)
          .addParticipant(kTrip1.id, 'new@test.com');

      expect(result, true);
      final updated =
          container.read(tripsProvider).trips.firstWhere((t) => t.id == kTrip1.id);
      // The fake addParticipant returns a trip with kParticipant2 appended
      expect(updated.participants.length, greaterThan(kTrip1.participants.length));
    });

    test('returns false and sets error on failure', () async {
      final fakeRepo = FakeTripRepository()..shouldFail = true;
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result = await container
          .read(tripsProvider.notifier)
          .addParticipant(kTrip1.id, 'new@test.com');

      expect(result, false);
      expect(container.read(tripsProvider).error, 'Failed to add participant.');
    });
  });

  group('TripsNotifier — removeParticipant', () {
    test('returns true and updates trip in list', () async {
      final fakeRepo = FakeTripRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result = await container
          .read(tripsProvider.notifier)
          .removeParticipant(kTrip1.id, kParticipant2.id);

      expect(result, true);
      final updated =
          container.read(tripsProvider).trips.firstWhere((t) => t.id == kTrip1.id);
      expect(
          updated.participants.any((p) => p.id == kParticipant2.id), false);
    });

    test('sets specific message when error contains "paid"', () async {
      final fakeRepo = FakeTripRepository()
        ..shouldFail = true
        ..failureMessage = 'User has paid expenses';
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      await container
          .read(tripsProvider.notifier)
          .removeParticipant(kTrip1.id, kParticipant2.id);

      expect(container.read(tripsProvider).error,
          'Cannot remove participant with existing expenses.');
    });

    test('sets specific message when error contains "split"', () async {
      final fakeRepo = FakeTripRepository()
        ..shouldFail = true
        ..failureMessage = 'User is in expense split';
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      await container
          .read(tripsProvider.notifier)
          .removeParticipant(kTrip1.id, kParticipant2.id);

      expect(container.read(tripsProvider).error,
          'Cannot remove participant with existing expenses.');
    });

    test('sets generic message for other errors', () async {
      final fakeRepo = FakeTripRepository()
        ..shouldFail = true
        ..failureMessage = 'server error';
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      await container
          .read(tripsProvider.notifier)
          .removeParticipant(kTrip1.id, kParticipant2.id);

      expect(container.read(tripsProvider).error,
          'Failed to remove participant.');
    });
  });

  group('TripsNotifier — updateTrip', () {
    test('returns true and replaces trip in list', () async {
      final fakeRepo = FakeTripRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result = await container
          .read(tripsProvider.notifier)
          .updateTrip(kTrip1.id, name: 'Rome');

      expect(result, true);
      final updated =
          container.read(tripsProvider).trips.firstWhere((t) => t.id == kTrip1.id);
      expect(updated.name, 'Rome');
    });

    test('does not change other trips when updating one', () async {
      final fakeRepo = FakeTripRepository();
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      await container
          .read(tripsProvider.notifier)
          .updateTrip(kTrip1.id, name: 'Rome');

      final other =
          container.read(tripsProvider).trips.firstWhere((t) => t.id == kTrip2.id);
      expect(other.name, kTrip2.name);
    });

    test('returns false and sets error on failure', () async {
      final fakeRepo = FakeTripRepository()..shouldFail = true;
      final container = makeContainer(fakeRepo);
      await waitForInit(container);

      final result = await container
          .read(tripsProvider.notifier)
          .updateTrip(kTrip1.id, name: 'Rome');

      expect(result, false);
      expect(container.read(tripsProvider).error, 'Failed to update trip.');
    });
  });
}
