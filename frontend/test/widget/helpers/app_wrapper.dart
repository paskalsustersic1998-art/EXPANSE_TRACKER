import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Wraps [screen] in a [ProviderScope] + [MaterialApp.router] with a minimal
/// [GoRouter] so that screens can call context.go() / context.push() without
/// crashing during widget tests.
Widget buildTestApp({
  required Widget screen,
  String initialRoute = '/',
  List<Override> overrides = const [],
}) {
  final router = GoRouter(
    initialLocation: initialRoute,
    routes: [
      GoRoute(path: initialRoute, builder: (ctx, st) => screen),
      GoRoute(path: '/login', builder: (ctx, st) => const _Stub('Login')),
      GoRoute(path: '/register', builder: (ctx, st) => const _Stub('Register')),
      GoRoute(path: '/trips', builder: (ctx, st) => const _Stub('Trips')),
      GoRoute(
        path: '/trips/:id',
        builder: (ctx, st) => const _Stub('Trip Detail'),
      ),
      GoRoute(path: '/admin', builder: (ctx, st) => const _Stub('Admin')),
    ],
  );

  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}

class _Stub extends StatelessWidget {
  const _Stub(this.label);
  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}
