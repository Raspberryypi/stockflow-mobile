import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/palette.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/user_avatar.dart';

class _MoreItem {
  const _MoreItem(this.label, this.path, this.icon, {this.adminOnly = false});
  final String label;
  final String path;
  final IconData icon;
  final bool adminOnly;
}

const _items = [
  _MoreItem('Categories', '/more/categories', Icons.category_rounded),
  _MoreItem('Locations', '/more/locations', Icons.place_rounded),
  _MoreItem('Purchase Orders', '/more/purchase-orders', Icons.local_shipping_rounded),
  _MoreItem('Reports', '/more/reports', Icons.assessment_rounded),
  _MoreItem('Profile', '/more/profile', Icons.person_rounded),
  _MoreItem('Users', '/more/users', Icons.people_rounded, adminOnly: true),
];

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final visible = _items.where((i) => !i.adminOnly || (user?.isAdmin ?? false)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppPalette.sidebarBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              UserAvatar(user, radius: 22, background: AppPalette.sidebarBgActive),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.name.isNotEmpty == true ? user!.name : 'User',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(
                      (user?.role ?? '').isEmpty
                          ? ''
                          : '${user!.role[0].toUpperCase()}${user.role.substring(1)}',
                      style: const TextStyle(color: AppPalette.sidebarText, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < visible.length; i++) ...[
                ListTile(
                  leading: Icon(visible[i].icon, color: AppPalette.primary),
                  title: Text(visible[i].label,
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                  trailing: Icon(Icons.chevron_right_rounded, color: p.textSecondary),
                  onTap: () => context.go(visible[i].path),
                ),
                if (i < visible.length - 1) const Divider(height: 1, indent: 16, endIndent: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: Icon(Icons.logout_rounded, color: p.textSecondary),
            title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            onTap: () => showConfirmDialog(
              context,
              title: 'Log out?',
              message: "You'll need to sign in again to access ${AppConfig.brandName}.",
              confirmLabel: 'Log out',
              destructive: false,
              onConfirm: () => context.read<AuthProvider>().logout(),
            ),
          ),
        ),
      ],
    );
  }
}
