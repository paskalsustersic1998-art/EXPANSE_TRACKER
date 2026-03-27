import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(),
);

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(authRepositoryProvider)),
);

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState()) {
    _restoreSession();
  }

  final AuthRepository _repo;

  Future<void> _restoreSession() async {
    state = state.copyWith(isLoading: true);
    final user = await _repo.getMe();
    state = AuthState(user: user);
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.login(email, password);
      final user = await _repo.getMe();
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _friendlyError(e),
        clearUser: true,
      );
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.register(email, password);
      await _repo.login(email, password);
      final user = await _repo.getMe();
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _friendlyError(e),
        clearUser: true,
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Email already registered')) return 'Email already registered.';
    if (msg.contains('Invalid email or password')) return 'Invalid email or password.';
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot reach server. Is the backend running?';
    }
    return 'Something went wrong. Please try again.';
  }
}
