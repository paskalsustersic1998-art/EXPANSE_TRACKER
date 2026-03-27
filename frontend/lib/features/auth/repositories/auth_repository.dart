import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants.dart';
import '../../../core/dio_client.dart';
import '../models/user_model.dart';

class AuthRepository {
  final Dio _dio = DioClient.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<UserModel> register(String email, String password) async {
    final response = await _dio.post(
      '/auth/register',
      data: {'email': email, 'password': password},
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> login(String email, String password) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final token = response.data['access_token'] as String;
    await _storage.write(key: ApiConstants.tokenKey, value: token);
  }

  Future<UserModel?> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: ApiConstants.tokenKey);
  }
}
