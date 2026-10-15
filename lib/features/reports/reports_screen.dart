import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/format.dart';
import '../../core/utils/print_table.dart';
import '../../services/report_service.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/page_container.dart';
import '../../widgets/print_table_button.dart';
import '../dashboard/stat_card.dart';

const _periods = [7, 30, 90, 180, 365];

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _days = 30;
  Map<String, dynamic>? _report;
  bool _loading = true;
  String _error = '';
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = ++_reqId;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final res = await ReportService.getInventoryReport({'days': _days});
      if (mounted && id == _reqId) setState(() => _report = asMap(res['data']));
    } catch (e) {
      if (mounted && id == _reqId) setState(() => _error = apiErrorMessage(e, 'Failed to load report.'));
    } finally {
      if (mounted && id == _reqId) setState(() => _loading = false);
    }
  }

  (String, String) get _period {
    final end = DateTime.now();
    return (formatDateInput(end.subtract(Duration(days: _days))), formatDateInput(end));
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    return RefreshIndicator(
      onRefresh: _load,
      child: PageContainer(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                const Spacer(),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<int>(
                    initialValue: _days,
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Period', isDense: true),
                    items: [
                      for (final d in _periods) DropdownMenuItem(value: d, child: Text('Last $d days')),
                    ],
                    onChanged: (v) {
                      if (v == null || v == _days) return;
                      setState(() => _days = v);
                      _load();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error.isNotEmpty) AppAlert(_error),
            if (report == null || (_loading && report.isEmpty))
              ..._skeleton()
            else ...[
              ..._kpis(report),
              const SizedBox(height: 16),
              _valueChart(report),
              const SizedBox(height: 16),
              _topMovers(report),
              const SizedBox(height: 16),
              _deadStock(report),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _skeleton() {
    final p = AppPalette.of(context);
    return [
      for (var i = 0; i < 4; i++)
        Container(
          height: 80,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: p.divider, borderRadius: BorderRadius.circular(16)),
        ),
    ];
  }

  List<Widget> _kpis(Map<String, dynamic> report) {
    final k = asMap(report['kpis']);
    final change = toNum(k['valueChange']);
    final cards = [
      StatCard(
        label: 'Current Inventory Value',
        value: formatCurrency(toNum(k['currentValue'])),
        icon: Icons.paid_rounded,
        tone: StatTone.primary,
        loading: _loading,
      ),
      StatCard(
        label: 'Value Change (${_days}d)',
        value: '${change >= 0 ? '+' : ''}${formatCurrency(change)}',
        icon: Icons.trending_up_rounded,
        tone: change >= 0 ? StatTone.success : StatTone.error,
        loading: _loading,
      ),
      StatCard(
        label: 'Turnover Rate',
        value: '${k['turnoverRate'] ?? 0}',
        icon: Icons.swap_vert_rounded,
        tone: StatTone.info,
        loading: _loading,
      ),
      StatCard(
        label: 'Dead Stock Value',
        value: formatCurrency(toNum(k['deadStockValue'])),
        icon: Icons.inventory_2_rounded,
        tone: StatTone.warning,
        loading: _loading,
      ),
    ];
    return [
      LayoutBuilder(
        builder: (_, c) {
          final cols = c.maxWidth >= 600 ? 2 : 1;
          final w = (c.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [for (final card in cards) SizedBox(width: w, child: card)],
          );
        },
      ),
    ];
  }

  Widget _section({required String title, String? caption, Widget? action, required Widget child}) {
    final p = AppPalette.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                ?action,
              ],
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(caption, style: TextStyle(fontSize: 12, color: p.textSecondary)),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _valueChart(Map<String, dynamic> report) {
    final p = AppPalette.of(context);
    final series = asMapList(report['valueOverTime']);
    final points = [...series]..sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
    final spots = [
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), toNum(points[i]['value']).toDouble()),
    ];
    final labelEvery = (points.length / 4).ceil().clamp(1, 1000);

    return _section(
      title: 'Inventory Value Over Time',
      caption: 'Valued at current prices; reconstructed from transaction history.',
      child: SizedBox(
        height: 220,
        child: spots.isEmpty
            ? Center(child: Text('No data for this period.', style: TextStyle(color: p.textSecondary)))
            : LineChart(
                LineChartData(
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: p.divider, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 56,
                        getTitlesWidget: (v, meta) => Text(
                          '₱${_compact(v)}',
                          style: TextStyle(fontSize: 10, color: p.textSecondary),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 24,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= points.length || i % labelEvery != 0) {
                            return const SizedBox.shrink();
                          }
                          final d = DateTime.tryParse('${points[i]['date']}');
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(d == null ? '' : '${d.month}/${d.day}',
                                style: TextStyle(fontSize: 10, color: p.textSecondary)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => [
                        for (final s in spots)
                          LineTooltipItem(
                            '${formatDate(points[s.x.toInt()]['date'])}\n${formatCurrency(s.y)}',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: AppPalette.primary,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppPalette.primary.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  static String _compact(double v) {
    final a = v.abs();
    if (a >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (a >= 1e3) return '${(v / 1e3).toStringAsFixed(a >= 1e4 ? 0 : 1)}k';
    return v.toStringAsFixed(0);
  }

  Widget _topMovers(Map<String, dynamic> report) {
    final p = AppPalette.of(context);
    final movers = asMapList(report['topMovers']);
    final max = movers.fold<num>(0, (m, e) => toNum(e['unitsOut']) > m ? toNum(e['unitsOut']) : m);
    return _section(
      title: 'Top Moving Products',
      child: movers.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.insights_outlined, size: 32, color: p.textSecondary.withValues(alpha: 0.6)),
                    const SizedBox(height: 8),
                    Text('No stock-out activity in this period.', style: TextStyle(color: p.textSecondary)),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                for (final m in movers)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('${m['name']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            Text('${formatInt(toNum(m['unitsOut']))} units',
                                style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: max == 0 ? 0 : toNum(m['unitsOut']) / max,
                            minHeight: 8,
                            color: AppPalette.info,
                            backgroundColor: p.infoLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('${m['sku']}', style: TextStyle(fontSize: 11.5, color: p.textSecondary)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _deadStock(Map<String, dynamic> report) {
    final p = AppPalette.of(context);
    final dead = asMapList(report['deadStock']);
    final deadDays = asMap(report['range'])['deadDays'] ?? 0;
    String sinceSold(Map<String, dynamic> d) =>
        d['daysSinceSold'] == null ? 'Never sold' : '${d['daysSinceSold']}';

    return _section(
      title: 'Dead Stock',
      caption: 'Products still in stock with no Stock Out activity in over $deadDays days.',
      action: dead.isEmpty
          ? null
          : PrintTableButton<Map<String, dynamic>>(
              title: 'Dead Stock Report',
              subtitle:
                  'Report period: last $_days days. Products still in stock with no Stock Out activity in over $deadDays days (as of today).',
              columns: [
                PrintColumn('Product', (d) => d['name']),
                PrintColumn('SKU', (d) => d['sku']),
                PrintColumn('Qty on hand', (d) => d['quantity'], alignRight: true),
                PrintColumn('Value', (d) => formatCurrency(toNum(d['value'])), alignRight: true),
                PrintColumn('Days since last sold', sinceSold, alignRight: true),
              ],
              getRows: (_, _) async => dead,
              fixedRange: _period,
            ),
      child: dead.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No dead stock — everything is moving.',
                    style: TextStyle(color: p.textSecondary)),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < dead.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: p.tableDivider),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${dead[i]['name']}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                '${dead[i]['sku']}  ·  Qty ${formatInt(toNum(dead[i]['quantity']))}  ·  ${dead[i]['daysSinceSold'] == null ? 'Never sold' : '${dead[i]['daysSinceSold']} days since sold'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(formatCurrency(toNum(dead[i]['value'])),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
