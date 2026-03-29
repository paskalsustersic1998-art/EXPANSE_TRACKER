import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/screens/admin_screen.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/expenses/screens/trip_detail_screen.dart';
import '../features/trips/screens/trips_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      // Still restoring session — stay put
      if (authState.isLoading) return null;

      final isLoggedIn = authState.isAuthenticated;
      final onAuthPage =
          state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (!isLoggedIn && !onAuthPage) return '/login';
      if (isLoggedIn && onAuthPage) return '/trips';

      // Protect /admin — non-admins get bounced to /trips
      if (state.matchedLocation == '/admin' &&
          authState.user?.role != 'admin') {
        return '/trips';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/trips',
        builder: (context, state) => const TripsScreen(),
      ),
      GoRoute(
        path: '/trips/:id',
        builder: (context, state) {
          final tripId = int.parse(state.pathParameters['id']!);
          final tripName = state.extra as String? ?? 'Trip';
          return TripDetailScreen(tripId: tripId, tripName: tripName);
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminScreen(),
      ),
    ],
  );
});
