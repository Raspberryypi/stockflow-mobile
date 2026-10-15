import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/format.dart';
import '../../services/product_service.dart';
import '../../services/transaction_service.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/page_container.dart';
import '../../widgets/status_chip.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _manual = TextEditingController();
  final _quantity = TextEditingController(text: '1');

  MobileScannerController? _controller;
  bool _scanning = false;

  Map<String, dynamic>? _product;
  bool _looking = false;
  String _lookupError = '';
  String _success = '';
  String _action = 'STOCK_OUT';
  bool _recording = false;

  @override
  void dispose() {
    _controller?.dispose();
    _manual.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
      _scanning = true;
      _lookupError = '';
    });
  }

  void _stopScan() {
    final old = _controller;
    setState(() {
      _controller = null;
      _scanning = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  void _onDetect(BarcodeCapture capture) {
    if (_looking) return;
    String? code;
    for (final b in capture.barcodes) {
      final v = b.rawValue?.trim();
      if (v != null && v.isNotEmpty) {
        code = v;
        break;
      }
    }
    if (code == null) return;
    _stopScan();
    _lookup(code);
  }

  Future<void> _lookup(String sku) async {
    setState(() {
      _looking = true;
      _lookupError = '';
      _success = '';
    });
    try {
      final res = await ProductService.getProductBySku(sku);
      if (!mounted) return;
      setState(() {
        _product = asMap(res['data']);
        _quantity.text = '1';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _product = null;
        _lookupError = apiErrorMessage(e, 'No product found for "$sku"');
      });
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  void _manualLookup() {
    final sku = _manual.text.trim();
    if (sku.isEmpty) return;
    FocusScope.of(context).unfocus();
    _lookup(sku);
  }

  Future<void> _record() async {
    final product = _product;
    final qty = int.tryParse(_quantity.text.trim());
    if (product == null || qty == null || qty <= 0) {
      setState(() => _lookupError = 'Enter a quantity greater than 0');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _recording = true;
      _success = '';
      _lookupError = '';
    });
    try {
      await TransactionService.createTransaction({
        'product': product['_id'],
        'type': _action,
        'quantity': qty,
        if (_action == 'STOCK_OUT') 'reason': 'Sold',
        'notes': 'Recorded via QR/barcode scan',
      });
      final label = _action == 'STOCK_OUT' ? 'Stock out' : 'Stock in';
      if (!mounted) return;
      setState(() => _success = '$label of $qty recorded for ${product['name']}.');
      final res = await ProductService.getProductBySku('${product['sku']}');
      if (mounted) setState(() => _product = asMap(res['data']));
    } catch (e) {
      if (mounted) setState(() => _lookupError = apiErrorMessage(e, 'Failed to record transaction'));
    } finally {
      if (mounted) setState(() => _recording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PageContainer(
          maxWidth: 760,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Scan Product',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                "Scan a product's QR/barcode label to look it up and log a stock movement.",
                style: TextStyle(color: p.textSecondary),
              ),
              const SizedBox(height: 16),
              _buildScanCard(p),
              const SizedBox(height: 16),
              _buildResultCard(p),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScanCard(AppPalette p) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (kIsWeb)
              AppAlert(
                'Camera scanning works in the Android/iOS app. In the browser, type the SKU below.',
                severity: AlertSeverity.info,
              )
            else if (_scanning && _controller != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 300,
                  child: MobileScanner(controller: _controller!, onDetect: _onDetect),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _stopScan,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop camera'),
              ),
            ] else
              FilledButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan with camera'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            const SizedBox(height: 14),
            Text(
              kIsWeb ? 'Look up by SKU:' : "No camera, or scanning isn't working? Type the SKU instead:",
              style: TextStyle(fontSize: 12.5, color: p.textSecondary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manual,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _manualLookup(),
                    decoration: const InputDecoration(hintText: 'e.g. SKU-1234', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _looking ? null : _manualLookup,
                  child: const Text('Look up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(AppPalette p) {
    final product = _product;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_looking)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
                    const SizedBox(width: 10),
                    Text('Looking up product\u2026', style: TextStyle(color: p.textSecondary)),
                  ],
                ),
              ),
            if (_lookupError.isNotEmpty) AppAlert(_lookupError),
            if (_success.isNotEmpty) AppAlert(_success, severity: AlertSeverity.success),
            if (product == null && !_looking && _lookupError.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    Icon(Icons.qr_code_scanner_rounded,
                        size: 40, color: p.textSecondary.withValues(alpha: 0.6)),
                    const SizedBox(height: 8),
                    Text('Scan a code to see product details here.',
                        textAlign: TextAlign.center, style: TextStyle(color: p.textSecondary)),
                  ],
                ),
              ),
            if (product != null) ..._productDetails(p, product),
          ],
        ),
      ),
    );
  }

  List<Widget> _productDetails(AppPalette p, Map<String, dynamic> product) {
    final category = asMap(product['category'])['name']?.toString() ?? 'Uncategorized';
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${product['name'] ?? ''}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('SKU: ${product['sku']} \u00B7 $category',
                    style: TextStyle(color: p.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip('${product['status'] ?? ''}'),
        ],
      ),
      const SizedBox(height: 8),
      Text.rich(TextSpan(children: [
        const TextSpan(text: 'Current stock: '),
        TextSpan(
            text: formatInt(toNum(product['quantity'])),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ])),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => context.go('/products?view=${product['_id']}'),
          icon: const Icon(Icons.visibility_outlined, size: 18),
          label: const Text('View full details'),
        ),
      ),
      const SizedBox(height: 16),
      Divider(color: p.divider),
      const SizedBox(height: 12),
      Text('Quick stock update',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'STOCK_OUT', label: Text('Stock Out')),
          ButtonSegment(value: 'STOCK_IN', label: Text('Stock In')),
        ],
        selected: {_action},
        onSelectionChanged: _recording ? null : (s) => setState(() => _action = s.first),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          SizedBox(
            width: 110,
            child: TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Qty', isDense: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _recording ? null : _record,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(_recording ? 'Recording\u2026' : 'Record'),
            ),
          ),
        ],
      ),
    ];
  }
}
