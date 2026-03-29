import 'package:dio/dio.dart';

import '../../../core/dio_client.dart';
import '../models/trip_model.dart';

class TripRepository {
  final Dio _dio = DioClient.instance;

  Future<List<TripModel>> getTrips() async {
    final response = await _dio.get('/trips');
    return (response.data as List<dynamic>)
        .map((t) => TripModel.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  Future<TripModel> createTrip(String name, String? description) async {
    final response = await _dio.post(
      '/trips',
      data: {'name': name, 'description': description},
    );
    return TripModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TripModel> getTrip(int id) async {
    final response = await _dio.get('/trips/$id');
    return TripModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TripModel> addParticipant(int tripId, String email) async {
    final response = await _dio.post(
      '/trips/$tripId/participants',
      data: {'email': email},
    );
    return TripModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteTrip(int tripId) async {
    await _dio.delete('/trips/$tripId');
  }

  Future<TripModel> removeParticipant(int tripId, int participantId) async {
    final response = await _dio.delete('/trips/$tripId/participants/$participantId');
    return TripModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<TripModel> updateTrip(int tripId, {String? name, String? description}) async {
    final response = await _dio.patch(
      '/trips/$tripId',
      data: {'name': name, 'description': description},
    );
    return TripModel.fromJson(response.data as Map<String, dynamic>);
  }
}
