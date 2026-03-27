import 'package:flutter_riverpod/flutter_riverpod.dart';

// Placeholder — replace with full auth state logic
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

class AuthState {
  final bool isAuthenticated;
  const AuthState({this.isAuthenticated = false});
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  // TODO: implement login(), logout(), restore session
}
