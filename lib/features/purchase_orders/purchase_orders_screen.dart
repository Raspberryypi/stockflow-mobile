import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/format.dart';
import '../../core/utils/print_table.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/list_widgets.dart';
import '../../widgets/page_container.dart';
import '../../widgets/print_table_button.dart';
import 'purchase_order_form_page.dart';

const _statuses = ['Draft', 'Ordered', 'Received', 'Cancelled'];

Color? _statusColor(String status) => switch (status) {
      'Ordered' => AppPalette.info,
      'Received' => AppPalette.success,
      'Cancelled' => AppPalette.error,
      _ => null,
    };

/// Port of pages/purchaseOrders/PurchaseOrderList.jsx.
class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final _searchCtl = TextEditingController();
  String _status = '';
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _suggestions = [];
  bool _suggestionsOpen = false;
  bool _loading = true;
  bool _busy = false;
  String _error = '';

  bool get _isAdmin => context.read<AuthProvider>().user?.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isAdmin) _loadSuggestions();
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final res = await PurchaseOrderService.getPurchaseOrders(_status.isEmpty ? {} : {'status': _status});
      if (mounted) setState(() => _orders = asMapList(res['data']));
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, 'Failed to load purchase orders.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final res = await PurchaseOrderService.getReorderSuggestions();
      if (mounted) setState(() => _suggestions = asMapList(res['data']));
    } catch (_) {
      if (mounted) setState(() => _suggestions = []);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_load(), if (_isAdmin) _loadSuggestions()]);
  }

  int get _totalSuggested =>
      _suggestions.fold(0, (sum, g) => sum + asMapList(g['items']).length);

  // Status is filtered on the server; the text search runs on the device.
  List<Map<String, dynamic>> get _visible {
    final term = _searchCtl.text.trim().toLowerCase();
    if (term.isEmpty) return _orders;
    return _orders
        .where((po) =>
            '${po['poNumber'] ?? ''}'.toLowerCase().contains(term) ||
            '${po['supplier'] ?? ''}'.toLowerCase().contains(term))
        .toList();
  }

  Future<void> _openForm({Map<String, dynamic>? order, Map<String, dynamic>? prefill}) async {
    final message = await Navigator.of(context, rootNavigator: true).push<String>(
      MaterialPageRoute(builder: (_) => PurchaseOrderFormPage(order: order, prefill: prefill)),
    );
    if (message != null && mounted) {
      showSnack(context, message);
      _refresh();
    }
  }

  Future<void> _markOrdered(Map<String, dynamic> po) async {
    setState(() => _busy = true);
    try {
      final res = await PurchaseOrderService.markOrdered('${po['_id']}');
      if (!mounted) return;
      showSnack(context, '${res['message'] ?? 'Order placed'}');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, apiErrorMessage(e, 'Failed to place order'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _receive(Map<String, dynamic> po) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => _ReceiveDialog(order: po),
    );
    if (message != null && mounted) {
      showSnack(context, message);
      _load();
    }
  }

  Future<void> _cancel(Map<String, dynamic> po) {
    return showConfirmDialog(
      context,
      title: 'Cancel this order?',
      message: '${po['poNumber']} will be marked cancelled. This cannot be undone.',
      confirmLabel: 'Cancel order',
      onConfirm: () async {
        try {
          final res = await PurchaseOrderService.cancelPurchaseOrder('${po['_id']}');
          if (!mounted) return;
          showSnack(context, '${res['message'] ?? 'Order cancelled'}');
          _load();
        } catch (e) {
          if (mounted) showSnack(context, apiErrorMessage(e, 'Action failed'));
        }
      },
    );
  }

  Future<void> _delete(Map<String, dynamic> po) {
    return showConfirmDialog(
      context,
      title: 'Delete this order?',
      message: '${po['poNumber']} will be permanently deleted.',
      confirmLabel: 'Delete',
      onConfirm: () async {
        try {
          await PurchaseOrderService.deletePurchaseOrder('${po['_id']}');
          if (!mounted) return;
          showSnack(context, 'Purchase order deleted');
          _load();
        } catch (e) {
          if (mounted) showSnack(context, apiErrorMessage(e, 'Action failed'));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;
    final visible = _visible;
    final search = _searchCtl.text.trim();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Purchase Order'),
            )
          : null,
      body: PageContainer(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      isDense: true,
                      decoration: const InputDecoration(labelText: 'Status', isDense: true),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('All statuses')),
                        for (final s in _statuses) DropdownMenuItem(value: s, child: Text(s)),
                      ],
                      onChanged: (v) {
                        setState(() => _status = v ?? '');
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  PrintTableButton<Map<String, dynamic>>(
                    title: 'Purchase Orders',
                    subtitle: [
                      if (_status.isNotEmpty) 'Status: $_status',
                      if (search.isNotEmpty) 'Search: "$search"',
                    ].join('  |  '),
                    columns: [
                      PrintColumn('PO Number', (po) => po['poNumber']),
                      PrintColumn('Supplier', (po) => po['supplier']),
                      PrintColumn('Status', (po) => po['status']),
                      PrintColumn('Items', (po) => asMapList(po['items']).length, alignRight: true),
                      PrintColumn('Total', (po) => formatCurrency(toNum(po['total'])), alignRight: true),
                      PrintColumn('Created', (po) => formatDate(po['createdAt'])),
                    ],
                    getRows: (_, _) async => visible,
                    dateOf: (po) => po['createdAt'],
                    dateLabel: 'created',
                    disabled: _loading,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: ListSearchField(
                controller: _searchCtl,
                hint: 'Search by PO number or supplier…',
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: _buildList(visible, isAdmin, search),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _suggestionsCard() {
    final p = AppPalette.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.lightbulb_outline_rounded, color: AppPalette.warningDark),
            title: Text('Reorder suggestions ($_totalSuggested)',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            trailing: Icon(_suggestionsOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            onTap: () => setState(() => _suggestionsOpen = !_suggestionsOpen),
          ),
          if (_suggestionsOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  for (final group in _suggestions)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: p.divider),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${group['supplier'] ?? ''}'.isEmpty
                                ? 'No supplier on file'
                                : '${group['supplier']}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            asMapList(group['items'])
                                .map((i) => '${asMap(i['product'])['name']} (${i['suggestedQuantity']})')
                                .join(', '),
                            style: TextStyle(fontSize: 12.5, color: p.textSecondary),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton(
                              onPressed: () => _openForm(prefill: group),
                              child: const Text('Create draft PO'),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> visible, bool isAdmin, String search) {
    if (_loading && _orders.isEmpty) return const ListStatus.loading();
    if (_error.isNotEmpty) return ListStatus.error(_error, onRetry: _load);

    final showSuggestions = isAdmin && _totalSuggested > 0;
    if (visible.isEmpty && !showSuggestions) {
      return ListStatus.empty(
        emptyIcon: Icons.inventory_2_outlined,
        emptyText: search.isNotEmpty || _status.isNotEmpty
            ? 'No purchase orders match your filters.'
            : 'No purchase orders yet.',
      );
    }

    final p = AppPalette.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        if (showSuggestions) ...[_suggestionsCard(), const SizedBox(height: 10)],
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
              search.isNotEmpty || _status.isNotEmpty
                  ? 'No purchase orders match your filters.'
                  : 'No purchase orders yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textSecondary),
            ),
          ),
        for (final po in visible) ...[
          _orderCard(po, isAdmin),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _orderCard(Map<String, dynamic> po, bool isAdmin) {
    final status = '${po['status'] ?? ''}';
    final items = asMapList(po['items']);
    final actions = <PopupMenuEntry<String>>[
      if (isAdmin && status == 'Draft') ...[
        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Edit'))),
        const PopupMenuItem(
            value: 'order',
            child: ListTile(
                leading: Icon(Icons.local_shipping_outlined, color: AppPalette.primary),
                title: Text('Place order'))),
        const PopupMenuItem(
            value: 'delete',
            child: ListTile(leading: Icon(Icons.delete_rounded, color: AppPalette.error), title: Text('Delete'))),
      ],
      if (status == 'Ordered') ...[
        const PopupMenuItem(
            value: 'receive',
            child: ListTile(
                leading: Icon(Icons.check_circle_outline_rounded, color: AppPalette.success),
                title: Text('Receive'))),
        if (isAdmin)
          const PopupMenuItem(
              value: 'cancel',
              child: ListTile(
                  leading: Icon(Icons.cancel_outlined, color: AppPalette.error), title: Text('Cancel order'))),
      ],
      if (isAdmin && status == 'Cancelled')
        const PopupMenuItem(
            value: 'delete',
            child: ListTile(leading: Icon(Icons.delete_rounded, color: AppPalette.error), title: Text('Delete'))),
    ];

    return ListRowCard(
      title: '${po['poNumber'] ?? ''}',
      titleTrailing: SmallChip(status, color: _statusColor(status)),
      lines: [
        '${po['supplier'] ?? ''}',
        '${items.length} item(s) · ${formatCurrency(toNum(po['total']))} · ${formatDate(po['createdAt'])}',
      ],
      onTap: (isAdmin && status == 'Draft') ? () => _openForm(order: po) : null,
      trailing: actions.isEmpty
          ? null
          : PopupMenuButton<String>(
              tooltip: 'Actions',
              enabled: !_busy,
              itemBuilder: (_) => actions,
              onSelected: (a) {
                switch (a) {
                  case 'edit':
                    _openForm(order: po);
                  case 'order':
                    _markOrdered(po);
                  case 'receive':
                    _receive(po);
                  case 'cancel':
                    _cancel(po);
                  case 'delete':
                    _delete(po);
                }
              },
            ),
    );
  }
}

/// Port of ReceivePODialog.jsx: confirms receiving and lets the user
/// override the order's put-away location. Pops the server's message.
class _ReceiveDialog extends StatefulWidget {
  const _ReceiveDialog({required this.order});
  final Map<String, dynamic> order;

  @override
  State<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<_ReceiveDialog> {
  List<Map<String, dynamic>> _locations = [];
  late String _location = '${asMap(widget.order['location'])['_id'] ?? ''}';
  String _error = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    LocationService.getLocations().then((res) {
      if (mounted) setState(() => _locations = asMapList(res['data']));
    }).catchError((_) {});
  }

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      final res = await PurchaseOrderService.receivePurchaseOrder(
          '${widget.order['_id']}', {'location': _location.isEmpty ? null : _location});
      if (mounted) Navigator.of(context).pop('${res['message'] ?? 'Order received'}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(e, 'Failed to receive order');
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // Keep the dropdown valid while locations load (or if one was archived).
    final known = _location.isEmpty || _locations.any((l) => '${l['_id']}' == _location);
    return AlertDialog(
      title: Text('Receive ${widget.order['poNumber']}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("This adds every item's quantity to stock and logs a Stock In transaction for each.",
                style: TextStyle(color: p.textSecondary)),
            const SizedBox(height: 16),
            if (_error.isNotEmpty) AppAlert(_error),
            DropdownButtonFormField<String>(
              key: ValueKey('${_locations.length}'),
              initialValue: known ? _location : '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Put away at'),
              items: [
                const DropdownMenuItem(value: '', child: Text('No specific location')),
                for (final l in _locations)
                  DropdownMenuItem(value: '${l['_id']}', child: Text('${l['name']}')),
              ],
              onChanged: _submitting ? null : (v) => setState(() => _location = v ?? ''),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _confirm,
          child: Text(_submitting ? 'Receiving…' : 'Receive order'),
        ),
      ],
    );
  }
}
