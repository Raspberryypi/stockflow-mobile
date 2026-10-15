import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/file_export.dart';
import '../../core/utils/format.dart';
import '../../services/product_service.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/page_container.dart';
import '../../widgets/status_chip.dart';

/// Port of ProductDetailsDialog.jsx as a full-screen page.
/// Pops with the product map when "Edit" is tapped (admin only), otherwise
/// pops with null.
class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({super.key, required this.productId, this.canEdit = false});
  final String productId;
  final bool canEdit;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  Map<String, dynamic>? _product;
  Map<String, dynamic>? _stock;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    // Per-location stock is a nice-to-have: its failure must not hide the product.
    ProductService.getProductStock(widget.productId).then((res) {
      if (mounted) setState(() => _stock = asMap(res['data']));
    }).catchError((_) {
      if (mounted) setState(() => _stock = null);
    });
    try {
      final res = await ProductService.getProduct(widget.productId);
      if (!mounted) return;
      setState(() => _product = asMap(res['data']));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e, 'Failed to load product.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadQr(String sku) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await saveOrShareFile(
        fileName: '$sku-qr.png',
        bytes: await _qrPng(sku),
        mimeType: 'image/png',
      );
      if (saved) messenger.showSnackBar(const SnackBar(content: Text('QR code saved.')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not save the QR code.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final product = _product;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          if (widget.canEdit && product != null)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => Navigator.of(context).pop(product),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PageContainer(
                  maxWidth: 760,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error.isNotEmpty) AppAlert(_error),
                      if (product != null) ..._content(context, product),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _content(BuildContext context, Map<String, dynamic> product) {
    final p = AppPalette.of(context);
    final imageUrl = product['imageUrl']?.toString() ?? '';
    final description = product['description']?.toString() ?? '';
    final category = asMap(product['category'])['name']?.toString();
    final supplier = product['supplier']?.toString() ?? '';
    final sku = '${product['sku'] ?? ''}';
    final levels = asMapList(_stock?['levels']);
    final unassigned = toNum(_stock?['unassigned']);

    return [
      // Header: name, SKU, status
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
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('SKU: $sku', style: TextStyle(color: p.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusChip('${product['status'] ?? ''}'),
        ],
      ),
      const SizedBox(height: 16),

      if (imageUrl.isNotEmpty) ...[
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 220,
            width: double.infinity,
            color: p.dark ? const Color(0xFF1E3336) : const Color(0xFFEEF4F6),
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.broken_image_outlined, color: p.textSecondary, size: 36),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],

      if (description.isNotEmpty) ...[
        Text(description),
        const SizedBox(height: 16),
      ],

      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 28,
            runSpacing: 16,
            children: [
              _Field('Category', category),
              _Field('Price', formatCurrency(toNum(product['price']))),
              _Field('Supplier', supplier),
              _Field('Quantity', formatInt(toNum(product['quantity']))),
              _Field('Minimum stock level', formatInt(toNum(product['minimumStockLevel']))),
            ],
          ),
        ),
      ),

      if (levels.isNotEmpty) ...[
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stock by location',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final l in levels)
                  _StockRow(
                      asMap(l['location'])['name']?.toString() ?? 'Unknown', toNum(l['quantity'])),
                if (unassigned > 0) _StockRow('Unassigned', unassigned, muted: true),
              ],
            ),
          ),
        ),
      ],

      const SizedBox(height: 16),
      Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Scan tag',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                color: Colors.white,
                child: QrImageView(
                  data: sku,
                  size: 170,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text('Encodes SKU: $sku',
                  style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _downloadQr(sku),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download PNG'),
              ),
              const SizedBox(height: 4),
              Text('Print this on a label, then use Scan Product to look it up or log stock.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
    ];
  }
}

/// Renders the SKU's QR code as a PNG with a white quiet zone, so the saved
/// file scans reliably once printed (the web's "Download PNG").
Future<Uint8List> _qrPng(String data, {double size = 512, double margin = 32}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final total = size + margin * 2;
  canvas.drawRect(Rect.fromLTWH(0, 0, total, total), Paint()..color = Colors.white);
  canvas.translate(margin, margin);
  QrPainter(
    data: data,
    version: QrVersions.auto,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
    dataModuleStyle:
        const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
  ).paint(canvas, Size(size, size));
  final image = await recorder.endRecording().toImage(total.toInt(), total.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final v = (value == null || value!.isEmpty) ? '\u2014' : value!;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 110, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow(this.name, this.quantity, {this.muted = false});
  final String name;
  final num quantity;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: TextStyle(color: muted ? p.textSecondary : p.textPrimary)),
          ),
          Text(formatInt(quantity), style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
