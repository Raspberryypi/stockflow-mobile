import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/format.dart';
import '../../services/location_service.dart';
import '../../services/purchase_order_service.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/page_container.dart';
import '../transactions/product_picker_sheet.dart';

class _Line {
  _Line({this.product, String quantity = '', String unitCost = ''})
      : quantity = TextEditingController(text: quantity),
        unitCost = TextEditingController(text: unitCost);

  Map<String, dynamic>? product;
  final TextEditingController quantity;
  final TextEditingController unitCost;

  void dispose() {
    quantity.dispose();
    unitCost.dispose();
  }
}

String _numText(Object? v) {
  final n = toNum(v);
  if (n == 0) return '';
  return n == n.roundToDouble() ? n.toInt().toString() : '$n';
}

/// Port of PurchaseOrderFormDialog.jsx as a full-screen page.
/// Creates or edits a Draft PO, optionally prefilled from a reorder
/// suggestion. Pops with the message to show once saved.
class PurchaseOrderFormPage extends StatefulWidget {
  const PurchaseOrderFormPage({super.key, this.order, this.prefill});
  final Map<String, dynamic>? order;
  final Map<String, dynamic>? prefill;

  @override
  State<PurchaseOrderFormPage> createState() => _PurchaseOrderFormPageState();
}

class _PurchaseOrderFormPageState extends State<PurchaseOrderFormPage> {
  final _scroll = ScrollController();
  final _supplier = TextEditingController();
  final _notes = TextEditingController();
  String _expectedDate = ''; // YYYY-MM-DD
  String _location = '';
  List<_Line> _lines = [];
  List<Map<String, dynamic>> _locations = [];
  String _error = '';
  bool _submitting = false;

  bool get _isEdit => widget.order != null;

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    final prefill = widget.prefill;
    if (order != null) {
      _supplier.text = '${order['supplier'] ?? ''}';
      final expected = '${order['expectedDate'] ?? ''}';
      _expectedDate = expected.length >= 10 ? expected.substring(0, 10) : '';
      _location = '${asMap(order['location'])['_id'] ?? ''}';
      _notes.text = '${order['notes'] ?? ''}';
      _lines = [
        for (final i in asMapList(order['items']))
          _Line(
            product: i['product'] is Map ? asMap(i['product']) : {'_id': i['product'], 'name': 'Product'},
            quantity: '${toNum(i['quantity']).toInt()}',
            unitCost: _numText(i['unitCost']),
          ),
      ];
    } else if (prefill != null) {
      _supplier.text = '${prefill['supplier'] ?? ''}';
      _lines = [
        for (final i in asMapList(prefill['items']))
          _Line(product: asMap(i['product']), quantity: '${toNum(i['suggestedQuantity']).toInt()}'),
      ];
    }
    if (_lines.isEmpty) _lines = [_Line()];

    LocationService.getLocations().then((res) {
      if (mounted) setState(() => _locations = asMapList(res['data']));
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _scroll.dispose();
    _supplier.dispose();
    _notes.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  num get _total => _lines.fold<num>(
      0, (sum, l) => sum + toNum(l.quantity.text) * toNum(l.unitCost.text));

  Future<void> _pickProduct(_Line line) async {
    final product = await showProductPicker(context);
    if (product != null && mounted) setState(() => line.product = product);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = DateTime.tryParse(_expectedDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _expectedDate =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  void _addLine() => setState(() => _lines.add(_Line()));

  void _removeLine(_Line line) {
    if (_lines.length == 1) return;
    setState(() => _lines.remove(line));
    line.dispose();
  }

  void _fail(String message) {
    setState(() => _error = message);
    _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _submit() async {
    if (_supplier.text.trim().isEmpty) return _fail('Supplier is required');
    final items = _lines.where((l) => l.product != null).toList();
    if (items.isEmpty) return _fail('Add at least one product');
    if (items.any((l) => toNum(l.quantity.text) <= 0)) {
      return _fail('Every line needs a positive quantity');
    }

    setState(() {
      _submitting = true;
      _error = '';
    });
    final payload = {
      'supplier': _supplier.text.trim(),
      'expectedDate': _expectedDate.isEmpty ? null : _expectedDate,
      'location': _location.isEmpty ? null : _location,
      'notes': _notes.text,
      'items': [
        for (final l in items)
          {
            'product': '${l.product!['_id']}',
            'quantity': toNum(l.quantity.text),
            'unitCost': toNum(l.unitCost.text),
          },
      ],
    };
    try {
      String message;
      if (_isEdit) {
        await PurchaseOrderService.updatePurchaseOrder('${widget.order!['_id']}', payload);
        message = 'Purchase order updated';
      } else {
        final res = await PurchaseOrderService.createPurchaseOrder(payload);
        message = '${res['message'] ?? 'Purchase order created'}';
      }
      if (mounted) Navigator.of(context).pop(message);
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _fail(apiErrorMessage(e, 'Failed to save purchase order'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final knownLocation = _location.isEmpty || _locations.any((l) => '${l['_id']}' == _location);
    final numberFormat = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit ${widget.order!['poNumber']}' : 'New Purchase Order'),
      ),
      body: PageContainer(
        maxWidth: 720,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_error.isNotEmpty) AppAlert(_error),
            TextField(
              controller: _supplier,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Supplier *'),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Expected date',
                  suffixIcon: _expectedDate.isEmpty
                      ? const Icon(Icons.calendar_today_rounded, size: 18)
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => setState(() => _expectedDate = ''),
                        ),
                ),
                child: Text(_expectedDate.isEmpty ? 'Not set' : formatDate(_expectedDate)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('loc-${_locations.length}'),
              initialValue: knownLocation ? _location : '',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Put-away location',
                helperText: 'Used when this order is received',
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('No specific location')),
                for (final l in _locations)
                  DropdownMenuItem(value: '${l['_id']}', child: Text('${l['name']}')),
              ],
              onChanged: (v) => setState(() => _location = v ?? ''),
            ),
            const SizedBox(height: 20),
            Text('Items', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final line in _lines)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickProduct(line),
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Product',
                                  suffixIcon: Icon(Icons.search_rounded),
                                ),
                                child: Text(
                                  line.product == null
                                      ? 'Choose a product'
                                      : '${line.product!['name']}${line.product!['sku'] == null ? '' : ' (${line.product!['sku']})'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: line.product == null ? p.textSecondary : null),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove line',
                            onPressed: _lines.length == 1 ? null : () => _removeLine(line),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: line.quantity,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: line.unitCost,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: numberFormat,
                                onChanged: (_) => setState(() {}),
                                decoration:
                                    const InputDecoration(labelText: 'Unit cost (₱)', isDense: true),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _addLine,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add item'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Total: ${formatCurrency(_total)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? 'Saving…' : (_isEdit ? 'Save changes' : 'Create draft')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
