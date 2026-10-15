import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/placeholder/not_found_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/locations/locations_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/purchase_orders/purchase_orders_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/users/users_screen.dart';
import '../../features/scan/scan_screen.dart';
import '../../features/transactions/transactions_screen.dart';
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
    errorBuilder: (_, _) => const NotFoundScreen(),
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
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
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
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, _) => const ForgotPasswordScreen()),

      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/scan', builder: (_, _) => const ScanScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/products',
              // Deep links: ?status=Low+Stock (notification bell), ?view=<id> (search).
              builder: (_, state) => ProductsScreen(
                initialStatus: state.uri.queryParameters['status'],
                viewId: state.uri.queryParameters['view'],
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/transactions', builder: (_, _) => const TransactionsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/more',
              builder: (_, _) => const MoreScreen(),
              routes: [
                GoRoute(path: 'categories', builder: (_, _) => const CategoriesScreen()),
                GoRoute(path: 'locations', builder: (_, _) => const LocationsScreen()),
                GoRoute(path: 'purchase-orders', builder: (_, _) => const PurchaseOrdersScreen()),
                GoRoute(path: 'reports', builder: (_, _) => const ReportsScreen()),
                GoRoute(path: 'profile', builder: (_, _) => const ProfileScreen()),
                GoRoute(path: 'users', builder: (_, _) => const UsersScreen()),
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
