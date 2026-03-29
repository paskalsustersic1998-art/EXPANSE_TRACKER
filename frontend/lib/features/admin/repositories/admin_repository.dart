import 'package:dio/dio.dart';

import '../../../core/dio_client.dart';
import '../../auth/models/user_model.dart';

class AdminRepository {
  final Dio _dio = DioClient.instance;

  Future<List<UserModel>> getUsers() async {
    final response = await _dio.get('/admin/users');
    return (response.data as List<dynamic>)
        .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  Future<UserModel> updateUserRole(int userId, String role) async {
    final response = await _dio.patch(
      '/admin/users/$userId/role',
      data: {'role': role},
    );
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }
}
