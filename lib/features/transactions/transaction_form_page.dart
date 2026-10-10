import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/format.dart';
import '../../services/location_service.dart';
import '../../services/product_service.dart';
import '../../services/transaction_service.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/page_container.dart';
import 'product_picker_sheet.dart';

const _stockOutReasons = ['Sold', 'Damaged', 'Returned to supplier', 'Other'];

/// Port of TransactionFormDialog.jsx as a full-screen page.
/// Pops with a short success message (e.g. "Stock in recorded") when saved.
class TransactionFormPage extends StatefulWidget {
  const TransactionFormPage({super.key});

  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _quantity = TextEditingController();
  final _supplier = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();

  String _type = 'STOCK_IN';
  Map<String, dynamic>? _product;
  Map<String, dynamic>? _stock; // per-location breakdown of the chosen product
  List<Map<String, dynamic>> _locations = [];
  String _reason = '';
  String _location = '';
  String _from = '';
  String _to = '';

  bool _submitting = false;
  String _error = '';

  bool get _isTransfer => _type == 'TRANSFER';

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [_quantity, _supplier, _reference, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final res = await LocationService.getLocations();
      if (mounted) setState(() => _locations = asMapList(res['data']));
    } catch (_) {
      if (mounted) setState(() => _locations = []);
    }
  }

  Future<void> _pickProduct() async {
    if (_submitting) return;
    final picked = await showProductPicker(context);
    if (picked == null || !mounted) return;
    setState(() {
      _product = picked;
      _stock = null;
    });
    // Show where this product's stock sits, so people can see what's available
    // before choosing a location / transfer source.
    try {
      final res = await ProductService.getProductStock('${picked['_id']}');
      if (mounted && _product?['_id'] == picked['_id']) {
        setState(() => _stock = asMap(res['data']));
      }
    } catch (_) {
      if (mounted) setState(() => _stock = null);
    }
  }

  void _scrollToTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _fail(String message) {
    setState(() {
      _error = message;
      _submitting = false;
    });
    _scrollToTop();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final product = _product;
    if (product == null) return _fail('Please select a product');
    if (!_formKey.currentState!.validate()) return;
    final quantity = int.parse(_quantity.text.trim());
    if (_isTransfer && _from == _to) return _fail('Choose two different locations');

    setState(() {
      _submitting = true;
      _error = '';
    });

    try {
      String message;
      if (_isTransfer) {
        await TransactionService.transferStock({
          'type': 'TRANSFER',
          'product': product['_id'],
          'from': _from.isEmpty ? null : _from,
          'to': _to.isEmpty ? null : _to,
          'quantity': quantity,
          'notes': _notes.text.trim(),
        });
        message = 'Stock transferred';
      } else {
        await TransactionService.createTransaction({
          'product': product['_id'],
          'type': _type,
          'quantity': quantity,
          'reason': _reason,
          'supplier': _supplier.text.trim(),
          'referenceNumber': _reference.text.trim(),
          'notes': _notes.text.trim(),
          'location': _location.isEmpty ? null : _location,
        });
        message = _type == 'STOCK_IN' ? 'Stock in recorded' : 'Stock out recorded';
      }
      if (mounted) Navigator.of(context).pop(message);
    } catch (e) {
      if (mounted) _fail(apiErrorMessage(e, 'Failed to record transaction'));
    }
  }

  List<DropdownMenuItem<String>> _locationItems(String emptyLabel) => [
        DropdownMenuItem(value: '', child: Text(emptyLabel)),
        for (final l in _locations)
          DropdownMenuItem(
            value: '${l['_id']}',
            child: Text('${l['name'] ?? ''}', overflow: TextOverflow.ellipsis),
          ),
      ];

  String _stockSummary() {
    final product = _product!;
    final buf = StringBuffer('Current stock: ${formatInt(toNum(product['quantity']))}');
    final levels = asMapList(_stock?['levels']);
    if (levels.isNotEmpty) {
      buf.write(' \u2014 ');
      buf.write(levels
          .map((l) =>
              '${asMap(l['location'])['name'] ?? 'Location'}: ${formatInt(toNum(l['quantity']))}')
          .join(', '));
      final unassigned = toNum(_stock?['unassigned']);
      if (unassigned > 0) buf.write(', Unassigned: ${formatInt(unassigned)}');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final product = _product;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: const Text('Record Transaction')),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          children: [
            PageContainer(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error.isNotEmpty) AppAlert(_error),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      const ButtonSegment(value: 'STOCK_IN', label: Text('Stock In')),
                      const ButtonSegment(value: 'STOCK_OUT', label: Text('Stock Out')),
                      ButtonSegment(
                        value: 'TRANSFER',
                        label: const Text('Transfer'),
                        enabled: _locations.isNotEmpty,
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged:
                        _submitting ? null : (s) => setState(() => _type = s.first),
                  ),
                  const SizedBox(height: 16),

                  // Product picker
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _pickProduct,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Product *',
                        suffixIcon: Icon(Icons.arrow_drop_down_rounded),
                      ),
                      child: Text(
                        product == null
                            ? 'Tap to choose a product'
                            : '${product['name']} (${product['sku']})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: product == null ? p.textSecondary : p.textPrimary),
                      ),
                    ),
                  ),
                  if (product != null) ...[
                    const SizedBox(height: 10),
                    AppAlert(_stockSummary(), severity: AlertSeverity.info),
                  ] else
                    const SizedBox(height: 14),

                  TextFormField(
                    controller: _quantity,
                    enabled: !_submitting,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Quantity *'),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      return (n == null || n <= 0) ? 'Quantity must be a positive number' : null;
                    },
                  ),
                  const SizedBox(height: 14),

                  if (_isTransfer) ...[
                    DropdownButtonFormField<String>(
                      key: const ValueKey('from'),
                      initialValue: _from,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'From'),
                      items: _locationItems('Unassigned'),
                      onChanged: _submitting ? null : (v) => _from = v ?? '',
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: const ValueKey('to'),
                      initialValue: _to,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'To'),
                      items: _locationItems('Unassigned'),
                      onChanged: _submitting ? null : (v) => _to = v ?? '',
                    ),
                    const SizedBox(height: 14),
                  ] else ...[
                    if (_locations.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        key: const ValueKey('location'),
                        initialValue: _location,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          helperText:
                              "Optional \u2014 leave blank if you don't track this movement by location",
                          helperMaxLines: 2,
                        ),
                        items: _locationItems('No specific location'),
                        onChanged: _submitting ? null : (v) => _location = v ?? '',
                      ),
                      const SizedBox(height: 14),
                    ],
                    if (_type == 'STOCK_IN')
                      TextFormField(
                        key: const ValueKey('supplier'),
                        controller: _supplier,
                        enabled: !_submitting,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Supplier'),
                      )
                    else
                      DropdownButtonFormField<String>(
                        key: const ValueKey('reason'),
                        initialValue: _reason.isEmpty ? null : _reason,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Reason'),
                        items: [
                          for (final r in _stockOutReasons)
                            DropdownMenuItem(value: r, child: Text(r)),
                        ],
                        onChanged: _submitting ? null : (v) => _reason = v ?? '',
                      ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _reference,
                      enabled: !_submitting,
                      decoration: const InputDecoration(labelText: 'Reference number'),
                    ),
                    const SizedBox(height: 14),
                  ],

                  TextFormField(
                    controller: _notes,
                    enabled: !_submitting,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: Text(_submitting ? 'Saving\u2026' : 'Record'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
