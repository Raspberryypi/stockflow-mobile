import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/csv.dart';
import '../../core/utils/file_export.dart';
import '../../core/utils/format.dart';
import '../../core/utils/print_table.dart';
import '../../services/transaction_service.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/page_container.dart';
import '../../widgets/print_table_button.dart';
import '../../widgets/transaction_type_chip.dart' show kTypeLabel;
import 'transaction_filters_sheet.dart';
import 'transaction_form_page.dart';
import 'transaction_tile.dart';

const _pageSize = 10;

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _scroll = ScrollController();
  final _searchCtl = TextEditingController();
  Timer? _debounce;

  String _search = '';
  String _type = '';
  String _startDate = '';
  String _endDate = '';

  List<Map<String, dynamic>> _items = [];
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String _error = '';
  int _reqId = 0;

  int get _filterCount =>
      TransactionFilterValues(type: _type, startDate: _startDate, endDate: _endDate).activeCount;
  bool get _hasAnyFilter => _search.isNotEmpty || _filterCount > 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _params(int page) {
    final params = <String, dynamic>{'page': page, 'limit': _pageSize};
    if (_search.isNotEmpty) params['search'] = _search;
    if (_type.isNotEmpty) params['type'] = _type;
    if (_startDate.isNotEmpty) params['startDate'] = _startDate;
    if (_endDate.isNotEmpty) params['endDate'] = _endDate;
    return params;
  }

  Future<void> _load() async {
    final id = ++_reqId;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final res = await TransactionService.getTransactions(_params(1));
      if (!mounted || id != _reqId) return;
      final pg = asMap(res['pagination']);
      final list = asMapList(res['data']);
      final totalPages = toNum(pg['totalPages']).toInt();
      setState(() {
        _items = list;
        _page = 1;
        _totalPages = totalPages < 1 ? 1 : totalPages;
        _total = pg['total'] == null ? list.length : toNum(pg['total']).toInt();
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() => _error = apiErrorMessage(e, 'Failed to load transactions.'));
    } finally {
      if (mounted && id == _reqId) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _totalPages) return;
    final id = _reqId;
    setState(() => _loadingMore = true);
    try {
      final res = await TransactionService.getTransactions(_params(_page + 1));
      if (!mounted || id != _reqId) return;
      setState(() {
        _items = [..._items, ...asMapList(res['data'])];
        _page += 1;
      });
    } catch (e) {
      if (mounted && id == _reqId) _snack(apiErrorMessage(e, 'Failed to load more transactions.'));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) _loadMore();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      final q = value.trim();
      if (q != _search) {
        _search = q;
        _load();
      }
    });
  }

  void _clearSearch() {
    _searchCtl.clear();
    _debounce?.cancel();
    setState(() {});
    if (_search.isNotEmpty) {
      _search = '';
      _load();
    }
  }

  void _clearAllFilters() {
    _searchCtl.clear();
    _debounce?.cancel();
    setState(() {
      _search = '';
      _type = '';
      _startDate = '';
      _endDate = '';
    });
    _load();
  }

  Future<void> _openFilters() async {
    final result = await showTransactionFiltersSheet(
      context,
      current: TransactionFilterValues(type: _type, startDate: _startDate, endDate: _endDate),
    );
    if (result == null || !mounted) return;
    setState(() {
      _type = result.type;
      _startDate = result.startDate;
      _endDate = result.endDate;
    });
    _load();
  }

  Future<void> _openForm() async {
    final message = await Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(builder: (_) => const TransactionFormPage()),
    );
    if (message != null && mounted) {
      _snack(message);
      _load();
    }
  }

  bool _exporting = false;

  Future<List<Map<String, dynamic>>> _fetchAll({String? from, String? to}) async {
    final params = _params(1)
      ..remove('page')
      ..['limit'] = 5000;
    if (from != null || to != null) {
      params.remove('startDate');
      params.remove('endDate');
      if (from != null && from.isNotEmpty) params['startDate'] = from;
      if (to != null && to.isNotEmpty) params['endDate'] = to;
    }
    final res = await TransactionService.getTransactions(params);
    return asMapList(res['data']);
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final rows = await _fetchAll();
      final saved = await saveOrShareFile(
        fileName: datedFileName('transactions-export', 'csv'),
        bytes: csvBytes(transactionsToCsv(rows)),
        mimeType: 'text/csv',
      );
      if (saved) _snack('Exported ${rows.length} transaction(s) to CSV.');
    } catch (_) {
      _snack('Failed to export transactions');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _print() {
    startPrintTable<Map<String, dynamic>>(
      context,
      title: 'Transactions',
      subtitle: [
        if (_type.isNotEmpty) 'Type: ${kTypeLabel[_type] ?? _type}',
        if (_search.isNotEmpty) 'Search: "$_search"',
      ].join('  |  '),
      columns: [
        PrintColumn('Date', (t) => formatDateTime(t['createdAt'])),
        PrintColumn('Product', (t) {
          final prod = asMap(t['product']);
          final sku = '${prod['sku'] ?? ''}';
          return '${prod['name'] ?? ''}${sku.isEmpty ? '' : ' ($sku)'}';
        }),
        PrintColumn('Type', (t) => kTypeLabel[t['type']] ?? t['type']),
        PrintColumn('Qty', (t) => t['quantity'], alignRight: true),
        PrintColumn('Location', describeLocation),
        PrintColumn('Reason / Supplier', (t) => t['type'] == 'STOCK_IN' ? t['supplier'] : t['reason']),
        PrintColumn('Reference', (t) => t['referenceNumber']),
        PrintColumn('By', (t) => asMap(t['performedBy'])['name']),
      ],
      getRows: (from, to) => _fetchAll(from: from, to: to),
      dateOf: (t) => t['createdAt'],
      dateLabel: 'recorded',
      initialFrom: _startDate,
      initialTo: _endDate,
      landscape: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record'),
      ),
      body: PageContainer(
        maxWidth: 900,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Transactions',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtl,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Search product, SKU, reference\u2026',
                            isDense: true,
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchCtl.text.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: _clearSearch,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Filters',
                        onPressed: _openFilters,
                        icon: Badge(
                          isLabelVisible: _filterCount > 0,
                          label: Text('$_filterCount'),
                          backgroundColor: AppPalette.primary,
                          child: const Icon(Icons.tune_rounded),
                        ),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'More actions',
                        enabled: !_exporting,
                        icon: _exporting
                            ? const SizedBox(
                                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.more_vert_rounded),
                        onSelected: (a) => a == 'export' ? _export() : _print(),
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'export',
                            child: ListTile(
                                leading: Icon(Icons.file_download_outlined), title: Text('Export CSV')),
                          ),
                          PopupMenuItem(
                            value: 'print',
                            child: ListTile(leading: Icon(Icons.print_outlined), title: Text('Print')),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!_loading && _error.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Text('$_total transaction${_total == 1 ? '' : 's'}',
                              style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                          const Spacer(),
                          if (_hasAnyFilter)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: p.textSecondary,
                              ),
                              onPressed: _clearAllFilters,
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              label: const Text('Clear filters'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: RefreshIndicator(onRefresh: _load, child: _buildList(p)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(AppPalette p) {
    const padding = EdgeInsets.fromLTRB(16, 8, 16, 96);

    if (_loading && _items.isEmpty) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => Container(
          height: 92,
          decoration: BoxDecoration(color: p.divider, borderRadius: BorderRadius.circular(16)),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [
          AppAlert(_error),
          Center(
            child: OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [
          const SizedBox(height: 56),
          Icon(Icons.swap_horiz_rounded, size: 40, color: p.textSecondary.withValues(alpha: 0.6)),
          const SizedBox(height: 8),
          Text(
            _hasAnyFilter
                ? 'No transactions match these filters.'
                : 'No transactions recorded yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textSecondary),
          ),
        ],
      );
    }

    final hasMore = _page < _totalPages;
    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: _items.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _loadingMore
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : TextButton(onPressed: _loadMore, child: const Text('Load more')),
            ),
          );
        }
        return TransactionTile(transaction: _items[i]);
      },
    );
  }
}
