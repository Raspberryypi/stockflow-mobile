import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/format.dart';
import '../../core/utils/print_table.dart';
import '../../widgets/print_table_button.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/transaction_type_chip.dart';

/// Shared "card with a title" frame used by the three dashboard sections.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.action});
  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                ?action,
              ],
            ),
            SizedBox(height: action == null ? 12 : 4),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: p.textSecondary.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: p.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Port of InventoryDistributionChart.jsx (donut instead of a pie).
class InventoryDistributionChart extends StatelessWidget {
  const InventoryDistributionChart({super.key, required this.data});
  final List<Map<String, dynamic>> data;

  static const _colors = [
    Color(0xFF2F6F6B),
    Color(0xFF3E8FB0),
    Color(0xFFE8A33D),
    Color(0xFFE1614D),
    Color(0xFF4CAF7D),
    Color(0xFF7C8FBF),
    Color(0xFFB98CC6),
    Color(0xFF5CA6A0),
  ];

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final total = data.fold<num>(0, (sum, e) => sum + toNum(e['quantity']).clamp(0, double.infinity));

    return _SectionCard(
      title: 'Inventory by Category',
      child: total <= 0
          ? const _EmptyState(icon: Icons.donut_large_rounded, message: 'No inventory data yet.')
          : Column(
              children: [
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 44,
                      sections: [
                        for (var i = 0; i < data.length; i++)
                          () {
                            final qty = toNum(data[i]['quantity']).clamp(0, double.infinity);
                            final share = total == 0 ? 0 : qty / total;
                            return PieChartSectionData(
                              value: qty.toDouble(),
                              color: _colors[i % _colors.length],
                              radius: 62,
                              title: share >= 0.07 ? formatInt(qty) : '',
                              titleStyle: const TextStyle(
                                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                            );
                          }(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < data.length; i++)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                                color: _colors[i % _colors.length], shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text('${data[i]['name'] ?? ''} · ${formatInt(toNum(data[i]['quantity']))}',
                              style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Port of LowStockTable.jsx as a list (a 5-column table doesn't fit a phone).
class LowStockList extends StatelessWidget {
  const LowStockList({super.key, required this.products});
  final List<Map<String, dynamic>> products;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return _SectionCard(
      title: 'Low & Out of Stock',
      action: products.isEmpty
          ? null
          : PrintTableButton<Map<String, dynamic>>(
              snapshot: true,
              title: 'Low & Out of Stock Products',
              columns: [
                PrintColumn('Product', (p) => p['name']),
                PrintColumn('SKU', (p) => p['sku']),
                PrintColumn('Qty', (p) => p['quantity'], alignRight: true),
                PrintColumn('Min', (p) => p['minimumStockLevel'], alignRight: true),
                PrintColumn('Status', (p) => p['status']),
              ],
              getRows: (_, _) async => products,
            ),
      child: products.isEmpty
          ? const _EmptyState(
              icon: Icons.inventory_rounded, message: 'All products are sufficiently stocked.')
          : Column(
              children: [
                for (var i = 0; i < products.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.tableDivider),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${products[i]['name'] ?? ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                '${products[i]['sku'] ?? ''}  ·  Qty ${formatInt(toNum(products[i]['quantity']))} / Min ${formatInt(toNum(products[i]['minimumStockLevel']))}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip('${products[i]['status'] ?? ''}'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Port of RecentTransactions.jsx as a list.
class RecentTransactionsList extends StatelessWidget {
  const RecentTransactionsList({super.key, required this.transactions});
  final List<Map<String, dynamic>> transactions;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return _SectionCard(
      title: 'Recent Transactions',
      action: transactions.isEmpty
          ? null
          : PrintTableButton<Map<String, dynamic>>(
              snapshot: true,
              title: 'Recent Transactions',
              columns: [
                PrintColumn('Product', (t) => asMap(t['product'])['name']),
                PrintColumn('Type', (t) => kTypeLabel[t['type']] ?? t['type']),
                PrintColumn('Qty', (t) => t['quantity'], alignRight: true),
                PrintColumn('By', (t) => asMap(t['performedBy'])['name']),
                PrintColumn('Date', (t) => formatDateTime(t['createdAt'])),
              ],
              getRows: (_, _) async => transactions,
            ),
      child: transactions.isEmpty
          ? const _EmptyState(
              icon: Icons.swap_horiz_rounded, message: 'No inventory movements yet.')
          : Column(
              children: [
                for (var i = 0; i < transactions.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.tableDivider),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(asMap(transactions[i]['product'])['name']?.toString() ?? '\u2014',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                '${asMap(transactions[i]['performedBy'])['name'] ?? '\u2014'}  ·  ${formatDate(transactions[i]['createdAt'])}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TransactionTypeChip('${transactions[i]['type'] ?? ''}'),
                            const SizedBox(height: 4),
                            Text('Qty ${formatInt(toNum(transactions[i]['quantity']))}',
                                style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
