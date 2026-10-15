import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/format.dart';
import '../../services/dashboard_service.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/page_container.dart';
import 'dashboard_cards.dart';
import 'greeting_header.dart';
import 'stat_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _stats == null;
      _error = '';
    });
    try {
      final res = await DashboardService.getStats();
      if (!mounted) return;
      setState(() => _stats = asMap(res['data']));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, 'Failed to load dashboard data.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    final l = _loading;

    final cards = <Widget>[
      StatCard(
        label: 'Total Products',
        value: formatInt(toNum(s?['totalProducts'])),
        icon: Icons.inventory_2_rounded,
        tone: StatTone.primary,
        loading: l,
      ),
      StatCard(
        label: 'Total Quantity',
        value: formatInt(toNum(s?['totalInventoryQuantity'])),
        icon: Icons.inventory_rounded,
        tone: StatTone.info,
        loading: l,
      ),
      StatCard(
        label: 'Inventory Value',
        value: formatCurrency(toNum(s?['totalInventoryValue'])),
        icon: Icons.paid_rounded,
        tone: StatTone.success,
        loading: l,
      ),
      StatCard(
        label: 'Low Stock',
        value: formatInt(toNum(s?['lowStockCount'])),
        icon: Icons.warning_amber_rounded,
        tone: StatTone.warning,
        loading: l,
      ),
      StatCard(
        label: 'Out of Stock',
        value: formatInt(toNum(s?['outOfStockCount'])),
        icon: Icons.error_outline_rounded,
        tone: StatTone.error,
        loading: l,
      ),
    ];

    final chart = InventoryDistributionChart(data: asMapList(s?['categoryBreakdown']));
    final lowStock = LowStockList(products: asMapList(s?['lowStockProducts']));
    final recent = RecentTransactionsList(transactions: asMapList(s?['recentTransactions']));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          PageContainer(
            maxWidth: 1100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GreetingHeader(),
                const SizedBox(height: 16),
                if (_error.isNotEmpty) AppAlert(_error),
                StatGrid(cards: cards),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (context, constraints) {
                  if (constraints.maxWidth >= 800) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: chart),
                        const SizedBox(width: 16),
                        Expanded(flex: 7, child: lowStock),
                      ],
                    );
                  }
                  return Column(children: [chart, const SizedBox(height: 16), lowStock]);
                }),
                const SizedBox(height: 16),
                recent,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
