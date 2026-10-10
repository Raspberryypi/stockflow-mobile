import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/placeholder/not_found_screen.dart';
import '../../features/placeholder/placeholder_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/shell/more_screen.dart';
import '../../providers/auth_provider.dart';

const _publicPaths = {'/login', '/register', '/forgot-password'};

/// Port of App.jsx routes + ProtectedRoute.jsx.
///
/// Web path            ->  Mobile path
///   /dashboard            /dashboard           (tab 1)
///   /scan                 /scan                (tab 2)
///   /products             /products            (tab 3)
///   /transactions         /transactions        (tab 4)
///   /categories ... /users  /more/<name>       (tab 5 "More")
GoRouter buildRouter(AuthProvider auth) {
  return GoRouter(
    initialLocation: '/splash',
    // Re-evaluates `redirect` whenever login state changes (login, logout, 401).
    refreshListenable: auth,
    errorBuilder: (_, __) => const NotFoundScreen(),
    redirect: (context, state) {
      final loc = state.uri.path;

      // Still verifying the stored token.
      if (auth.loading) return loc == '/splash' ? null : '/splash';

      if (!auth.isAuthenticated) {
        return _publicPaths.contains(loc) ? null : '/login';
      }

      // Logged in: keep them out of the auth screens.
      if (_publicPaths.contains(loc) || loc == '/splash' || loc == '/') {
        return '/dashboard';
      }

      // Frontend role check (the backend remains the real boundary).
      if (loc.startsWith('/more/users') && !(auth.user?.isAdmin ?? false)) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _Splash()),
      GoRoute(
        path: '/login',
        builder: (_, state) {
          final extra = (state.extra as Map?) ?? const {};
          return LoginScreen(
            verified: extra['verified'] == true,
            passwordReset: extra['passwordReset'] == true,
            email: extra['email'] as String?,
          );
        },
      ),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/scan', builder: (_, __) => const PlaceholderScreen('Scan Product', icon: Icons.qr_code_scanner_rounded)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/products', builder: (_, __) => const PlaceholderScreen('Products', icon: Icons.inventory_2_rounded)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/transactions', builder: (_, __) => const PlaceholderScreen('Transactions', icon: Icons.swap_horiz_rounded)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/more',
              builder: (_, __) => const MoreScreen(),
              routes: [
                GoRoute(path: 'categories', builder: (_, __) => const PlaceholderScreen('Categories', icon: Icons.category_rounded)),
                GoRoute(path: 'locations', builder: (_, __) => const PlaceholderScreen('Locations', icon: Icons.place_rounded)),
                GoRoute(path: 'purchase-orders', builder: (_, __) => const PlaceholderScreen('Purchase Orders', icon: Icons.local_shipping_rounded)),
                GoRoute(path: 'reports', builder: (_, __) => const PlaceholderScreen('Reports', icon: Icons.assessment_rounded)),
                GoRoute(path: 'profile', builder: (_, __) => const PlaceholderScreen('Profile', icon: Icons.person_rounded)),
                GoRoute(path: 'users', builder: (_, __) => const PlaceholderScreen('Users', icon: Icons.people_rounded)),
              ],
            ),
          ]),
        ],
      ),
    ],
  );
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
