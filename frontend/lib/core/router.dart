import 'package:go_router/go_router.dart';

import '../features/auth/screens/login_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    // Add more routes here as features are built:
    // GoRoute(path: '/trips', builder: ...),
    // GoRoute(path: '/trips/:id', builder: ...),
  ],
);
