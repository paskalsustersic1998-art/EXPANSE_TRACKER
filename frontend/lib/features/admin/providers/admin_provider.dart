import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/models/user_model.dart';
import '../repositories/admin_repository.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (_) => AdminRepository(),
);

final adminProvider = StateNotifierProvider<AdminNotifier, AdminState>(
  (ref) => AdminNotifier(ref.read(adminRepositoryProvider)),
);

class AdminState {
  final List<UserModel> users;
  final bool isLoading;
  final String? error;

  const AdminState({
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  AdminState copyWith({
    List<UserModel>? users,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AdminState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AdminNotifier extends StateNotifier<AdminState> {
  AdminNotifier(this._repo) : super(const AdminState()) {
    loadUsers();
  }

  final AdminRepository _repo;

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final users = await _repo.getUsers();
      state = state.copyWith(users: users, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Failed to load users.');
    }
  }

  Future<bool> updateRole(int userId, String role) async {
    try {
      final updated = await _repo.updateUserRole(userId, role);
      state = state.copyWith(
        users: [
          for (final u in state.users)
            if (u.id == userId) updated else u,
        ],
      );
      return true;
    } catch (_) {
      state = state.copyWith(error: 'Failed to update role.');
      return false;
    }
  }
}
