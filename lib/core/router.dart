import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/pos_screen.dart';
import '../screens/kitchen_screen.dart';
import '../screens/history_screen.dart';
import '../screens/printer_settings_screen.dart';
import '../screens/product_management_screen.dart';
import '../screens/shell_screen.dart';

class _GoRouterRefreshNotifier extends ChangeNotifier {
  _GoRouterRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (prev, next) {
      if (prev?.isLoggedIn != next.isLoggedIn) notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _GoRouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      if (authState.isLoading) return null;
      final loggedIn = authState.isLoggedIn;
      final onLogin = state.matchedLocation == '/login';
      if (!loggedIn && !onLogin) return '/login';
      if (loggedIn && onLogin) return '/pos';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 200),
        ),
      ),
      ShellRoute(
        pageBuilder: (context, state, child) => CustomTransitionPage(
          key: state.pageKey,
          child: ShellScreen(child: child),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 200),
        ),
        routes: [
          GoRoute(
            path: '/pos',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const PosScreen(),
            ),
          ),
          GoRoute(
            path: '/kitchen',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const KitchenScreen(),
            ),
          ),
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const HistoryScreen(),
            ),
          ),
          GoRoute(
            path: '/printer',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const PrinterSettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/products',
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: const ProductManagementScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
