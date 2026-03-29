import 'package:expanse_tracker/features/trips/models/trip_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseJson = {
    'id': 10,
    'name': 'Paris Trip',
    'description': 'Fun times',
    'created_by': 1,
    'created_at': '2024-06-01T00:00:00',
    'participants': [
      {'id': 1, 'email': 'alice@test.com'},
      {'id': 2, 'email': 'bob@test.com'},
    ],
  };

  group('ParticipantModel.fromJson', () {
    test('parses id and email', () {
      final p = ParticipantModel.fromJson({'id': 5, 'email': 'x@y.com'});
      expect(p.id, 5);
      expect(p.email, 'x@y.com');
    });
  });

  group('TripModel.fromJson', () {
    test('parses all fields correctly', () {
      final trip = TripModel.fromJson(baseJson);

      expect(trip.id, 10);
      expect(trip.name, 'Paris Trip');
      expect(trip.description, 'Fun times');
      expect(trip.createdBy, 1);
      expect(trip.createdAt, DateTime.parse('2024-06-01T00:00:00'));
    });

    test('parses participants list', () {
      final trip = TripModel.fromJson(baseJson);

      expect(trip.participants.length, 2);
      expect(trip.participants[0].id, 1);
      expect(trip.participants[0].email, 'alice@test.com');
      expect(trip.participants[1].id, 2);
      expect(trip.participants[1].email, 'bob@test.com');
    });

    test('parses null description as null', () {
      final trip = TripModel.fromJson({...baseJson, 'description': null});
      expect(trip.description, isNull);
    });

    test('parses empty participants list without error', () {
      final trip = TripModel.fromJson({...baseJson, 'participants': []});
      expect(trip.participants, isEmpty);
    });

    test('parses single participant', () {
      final trip = TripModel.fromJson({
        ...baseJson,
        'participants': [
          {'id': 3, 'email': 'solo@test.com'}
        ],
      });
      expect(trip.participants.length, 1);
      expect(trip.participants[0].email, 'solo@test.com');
    });
  });
}
