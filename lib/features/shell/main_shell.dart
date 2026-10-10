import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/palette.dart';
import '../../models/alert_stats.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_mode_provider.dart';
import '../../services/dashboard_service.dart';
import '../../widgets/user_avatar.dart';
import '../search/global_search_page.dart';
import 'notifications_sheet.dart';

/// Titles for pages that live under the "More" tab.
const _subPageTitles = {
  '/more/categories': 'Categories',
  '/more/locations': 'Locations',
  '/more/purchase-orders': 'Purchase Orders',
  '/more/reports': 'Reports',
  '/more/profile': 'Profile',
  '/more/users': 'Users',
};

/// Mobile replacement for MainLayout.jsx. The web's sidebar becomes:
///   - bottom navigation (Dashboard, Scan, Products, Transactions, More)
///   - a "More" tab holding the remaining pages + logout
/// The top bar keeps the web header's tools: search, alerts bell, dark mode, avatar.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  Timer? _timer;
  AlertStats _stats = const AlertStats();

  @override
  void initState() {
    super.initState();
    // MainShell mounts once per authenticated session, so one interval here
    // keeps the bell fresh across navigation (same 60s as the web).
    _refreshAlerts();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _refreshAlerts());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refreshAlerts() async {
    try {
      final res = await DashboardService.getStats();
      if (!mounted) return;
      setState(() => _stats = AlertStats.fromDashboard(Map<String, dynamic>.from(res['data'] as Map)));
    } catch (_) {
      // Silently ignore - the bell just won't update this cycle.
    }
  }

  Future<void> _openNotifications() async {
    _refreshAlerts();
    final isAdmin = context.read<AuthProvider>().user?.isAdmin ?? false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => NotificationsSheet(stats: _stats, isAdmin: isAdmin),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeMode = context.watch<ThemeModeProvider>();
    final path = GoRouterState.of(context).uri.path;
    final subTitle = _subPageTitles[path];
    final isSubPage = subTitle != null;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: isSubPage ? 0 : 16,
        leading: isSubPage
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.go('/more'),
              )
            : null,
        title: isSubPage
            ? Text(subTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18))
            : Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppPalette.sidebarBgActive,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warehouse_rounded, color: Colors.white, size: 19),
                  ),
                  const SizedBox(width: 10),
                  const Text(AppConfig.brandName,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ],
              ),
        actions: [
          IconButton(
            tooltip: 'Search products',
            icon: const Icon(Icons.search_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GlobalSearchPage()),
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: _stats.total > 0,
              label: Text(_stats.total > 99 ? '99+' : '${_stats.total}'),
              backgroundColor: AppPalette.error,
              child: const Icon(Icons.notifications_none_rounded),
            ),
            onPressed: _openNotifications,
          ),
          IconButton(
            tooltip: themeMode.isDark ? 'Switch to light mode' : 'Switch to dark mode',
            icon: Icon(themeMode.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: themeMode.toggle,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, right: 12),
            child: GestureDetector(
              onTap: () => context.go('/more/profile'),
              child: UserAvatar(auth.user, radius: 16, background: AppPalette.primary),
            ),
          ),
        ],
      ),
      body: widget.shell,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppPalette.sidebarBg,
          indicatorColor: AppPalette.sidebarBgActive,
          surfaceTintColor: Colors.transparent,
          height: 68,
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
                color: states.contains(WidgetState.selected) ? Colors.white : AppPalette.sidebarText,
              )),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                fontSize: 12,
                fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
                color: states.contains(WidgetState.selected) ? Colors.white : AppPalette.sidebarText,
              )),
        ),
        child: NavigationBar(
          selectedIndex: widget.shell.currentIndex,
          onDestinationSelected: (i) =>
              widget.shell.goBranch(i, initialLocation: i == widget.shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.qr_code_scanner_rounded), label: 'Scan'),
            NavigationDestination(icon: Icon(Icons.inventory_2_rounded), label: 'Products'),
            NavigationDestination(icon: Icon(Icons.swap_horiz_rounded), label: 'Transactions'),
            NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'More'),
          ],
        ),
      ),
    );
  }
}
