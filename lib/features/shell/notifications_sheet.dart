import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/palette.dart';
import '../../models/alert_stats.dart';
import '../../services/dashboard_service.dart';

class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key, required this.stats, required this.isAdmin});
  final AlertStats stats;
  final bool isAdmin;

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  bool _sending = false;

  Future<void> _sendNow() async {
    setState(() => _sending = true);
    try {
      await DashboardService.sendLowStockAlertNow();
    } catch (_) {
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final s = widget.stats;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Notifications',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            if (s.total == 0)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('No stock alerts right now.', style: TextStyle(color: p.textSecondary)),
              ),
            if (s.outOfStockCount > 0)
              ListTile(
                leading: const Icon(Icons.error_outline_rounded, color: AppPalette.error),
                title: Text('${s.outOfStockCount} product(s) out of stock',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            for (final prod in s.lowStockProducts.take(5))
              ListTile(
                leading: const Icon(Icons.warning_amber_rounded, color: AppPalette.warning),
                title: Text('${prod['name'] ?? ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
                subtitle: Text('${prod['quantity']} left (min ${prod['minimumStockLevel']})',
                    style: TextStyle(fontSize: 12, color: p.textSecondary)),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/products?status=Low+Stock');
                },
              ),
            if (s.total > 0)
              ListTile(
                title: const Text('View all products',
                    style: TextStyle(color: AppPalette.primary, fontWeight: FontWeight.w600, fontSize: 14)),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/products');
                },
              ),
            if (widget.isAdmin && s.total > 0)
              ListTile(
                leading: const Icon(Icons.mark_email_read_rounded),
                title: Text(_sending ? 'Sending…' : 'Email this alert now',
                    style: const TextStyle(fontSize: 14)),
                enabled: !_sending,
                onTap: _sendNow,
              ),
          ],
        ),
      ),
    );
  }
}
