import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';

final tripRepositoryProvider = Provider<TripRepository>(
  (_) => TripRepository(),
);

final tripsProvider = StateNotifierProvider<TripsNotifier, TripsState>(
  (ref) => TripsNotifier(ref.read(tripRepositoryProvider)),
);

class TripsState {
  final List<TripModel> trips;
  final bool isLoading;
  final String? error;

  const TripsState({
    this.trips = const [],
    this.isLoading = false,
    this.error,
  });

  TripsState copyWith({
    List<TripModel>? trips,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return TripsState(
      trips: trips ?? this.trips,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class TripsNotifier extends StateNotifier<TripsState> {
  TripsNotifier(this._repo) : super(const TripsState()) {
    loadTrips();
  }

  final TripRepository _repo;

  Future<void> loadTrips() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final trips = await _repo.getTrips();
      state = state.copyWith(trips: trips, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load trips.');
    }
  }

  Future<bool> createTrip(String name, String? description) async {
    try {
      final trip = await _repo.createTrip(name, description);
      state = state.copyWith(trips: [trip, ...state.trips]);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create trip.');
      return false;
    }
  }

  Future<bool> addParticipant(int tripId, String email) async {
    try {
      final updatedTrip = await _repo.addParticipant(tripId, email);
      state = state.copyWith(
        trips: [
          for (final t in state.trips)
            if (t.id == tripId) updatedTrip else t,
        ],
      );
      return true;
    } catch (_) {
      state = state.copyWith(error: 'Failed to add participant.');
      return false;
    }
  }

  Future<bool> deleteTrip(int tripId) async {
    try {
      await _repo.deleteTrip(tripId);
      state = state.copyWith(
        trips: state.trips.where((t) => t.id != tripId).toList(),
      );
      return true;
    } catch (e) {
      final msg = e.toString().contains('unsettled')
          ? 'Settle expenses before deleting this trip.'
          : 'Failed to delete trip.';
      state = state.copyWith(error: msg);
      return false;
    }
  }

  Future<bool> removeParticipant(int tripId, int participantId) async {
    try {
      final updatedTrip = await _repo.removeParticipant(tripId, participantId);
      state = state.copyWith(
        trips: [
          for (final t in state.trips)
            if (t.id == tripId) updatedTrip else t,
        ],
      );
      return true;
    } catch (e) {
      final msg = e.toString().contains('paid') || e.toString().contains('split')
          ? 'Cannot remove participant with existing expenses.'
          : 'Failed to remove participant.';
      state = state.copyWith(error: msg);
      return false;
    }
  }

  Future<bool> updateTrip(int tripId, {String? name, String? description}) async {
    try {
      final updatedTrip = await _repo.updateTrip(tripId, name: name, description: description);
      state = state.copyWith(
        trips: [
          for (final t in state.trips)
            if (t.id == tripId) updatedTrip else t,
        ],
      );
      return true;
    } catch (_) {
      state = state.copyWith(error: 'Failed to update trip.');
      return false;
    }
  }
}
