import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/cloudinary_upload.dart';
import '../../core/utils/format.dart';
import '../../services/product_service.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/page_container.dart';

/// Port of ProductFormDialog.jsx as a full-screen page.
/// [productId] null = Add, otherwise Edit (a fresh copy is fetched first).
/// Pops with `true` once the product was saved.
class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, this.productId, required this.categories});
  final String? productId;
  final List<Map<String, dynamic>> categories;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _description = TextEditingController();
  final _supplier = TextEditingController();
  final _price = TextEditingController();
  final _quantity = TextEditingController();
  final _minimum = TextEditingController();

  String _category = '';
  bool _discontinued = false;
  String _imageUrl = '';

  // Image chosen here but not uploaded yet: it is uploaded when Save is
  // tapped, so cancelling never leaves an unused file behind.
  XFile? _pendingFile;
  Uint8List? _pendingBytes;

  bool _loading = false;
  bool _submitting = false;
  String _error = '';

  bool get _isEdit => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadProduct();
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final c in [_name, _sku, _description, _supplier, _price, _quantity, _minimum]) {
      c.dispose();
    }
    super.dispose();
  }

  String _numText(Object? v) {
    if (v == null) return '';
    if (v is num && v == v.roundToDouble()) return v.toInt().toString();
    return '$v';
  }

  Future<void> _loadProduct() async {
    setState(() => _loading = true);
    try {
      final res = await ProductService.getProduct(widget.productId!);
      final p = asMap(res['data']);
      if (!mounted) return;
      final cat = p['category'];
      setState(() {
        _name.text = '${p['name'] ?? ''}';
        _sku.text = '${p['sku'] ?? ''}';
        _description.text = '${p['description'] ?? ''}';
        _supplier.text = '${p['supplier'] ?? ''}';
        _price.text = _numText(p['price']);
        _quantity.text = _numText(p['quantity']);
        _minimum.text = _numText(p['minimumStockLevel']);
        _category = cat is Map ? '${cat['_id'] ?? ''}' : '${cat ?? ''}';
        _imageUrl = '${p['imageUrl'] ?? ''}';
        _discontinued = p['status'] == 'Discontinued';
      });
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, 'Failed to load product.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    if (_submitting) return;
    try {
      final file = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 85);
      if (file == null) return;
      final problem = await validateProductImage(file);
      if (problem.isNotEmpty) {
        setState(() => _error = problem);
        _scrollToTop();
        return;
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _error = '';
        _pendingFile = file;
        _pendingBytes = bytes;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the image picker.');
    }
  }

  void _removeImage() => setState(() {
        _pendingFile = null;
        _pendingBytes = null;
        _imageUrl = '';
      });

  void _scrollToTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  String _messageFor(Object e, String fallback) {
    if (e is DioException) return apiErrorMessage(e, fallback);
    final text = e.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? fallback : text;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = '';
    });

    // Upload a newly chosen image first. If saving then fails (e.g. duplicate
    // SKU) the uploaded URL is kept, so a retry doesn't upload it again.
    var imageUrl = _imageUrl;
    final pending = _pendingFile;
    if (pending != null) {
      try {
        imageUrl = await uploadProductImage(pending);
        if (mounted) {
          setState(() {
            _imageUrl = imageUrl;
            _pendingFile = null;
            _pendingBytes = null;
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = _messageFor(e, 'Failed to upload image');
          _submitting = false;
        });
        _scrollToTop();
        return;
      }
    }

    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'sku': _sku.text.trim(),
      'description': _description.text.trim(),
      'category': _category,
      'price': num.parse(_price.text.trim()),
      'quantity': int.parse(_quantity.text.trim()),
      'minimumStockLevel': int.parse(_minimum.text.trim()),
      'supplier': _supplier.text.trim(),
      'imageUrl': imageUrl,
      // The backend re-derives the status unless it is Discontinued.
      'status': _discontinued ? 'Discontinued' : 'In Stock',
    };

    try {
      if (_isEdit) {
        await ProductService.updateProduct(widget.productId!, payload);
      } else {
        await ProductService.createProduct(payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = apiErrorMessage(e, 'Failed to save product');
        _submitting = false;
      });
      _scrollToTop();
    }
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  String? _money(String? v) {
    if (v == null || v.trim().isEmpty) return 'Price is required';
    final n = num.tryParse(v.trim());
    if (n == null || n < 0) return 'Enter a valid price';
    return null;
  }

  String? _wholeNumber(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    final n = int.tryParse(v.trim());
    if (n == null || n < 0) return 'Enter a whole number (0 or more)';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final categoryIds = widget.categories.map((c) => '${c['_id']}').toSet();
    final hasImage = _pendingBytes != null || _imageUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: Text(_isEdit ? 'Edit Product' : 'Add Product')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
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
                        TextFormField(
                          controller: _name,
                          enabled: !_submitting,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Product name *'),
                          validator: (v) => _required(v, 'Product name'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _sku,
                          enabled: !_submitting,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'SKU *'),
                          validator: (v) => _required(v, 'SKU'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _description,
                          enabled: !_submitting,
                          minLines: 2,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(labelText: 'Description'),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: categoryIds.contains(_category) ? _category : null,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Category *'),
                          items: [
                            for (final c in widget.categories)
                              DropdownMenuItem(
                                value: '${c['_id']}',
                                child: Text('${c['name'] ?? ''}', overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: _submitting ? null : (v) => _category = v ?? '',
                          validator: (v) =>
                              (v == null || v.isEmpty) ? 'Category is required' : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _supplier,
                          enabled: !_submitting,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Supplier'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _price,
                          enabled: !_submitting,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                          decoration: const InputDecoration(labelText: 'Price (\u20B1) *'),
                          validator: _money,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _quantity,
                                enabled: !_submitting,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(labelText: 'Quantity *'),
                                validator: (v) => _wholeNumber(v, 'Quantity'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _minimum,
                                enabled: !_submitting,
                                keyboardType: TextInputType.number,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: const InputDecoration(labelText: 'Min. stock level *'),
                                validator: (v) => _wholeNumber(v, 'Minimum stock level'),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('For routine stock movements, prefer the Transactions page.',
                              style: TextStyle(fontSize: 12, color: p.textSecondary)),
                        ),
                        const SizedBox(height: 20),
                        Text('Product image',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        _ImageBox(
                          bytes: _pendingBytes,
                          url: _imageUrl,
                          uploading: _submitting && _pendingFile != null,
                          onTap: _pickImage,
                        ),
                        if (hasImage)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _pendingFile != null
                                      ? 'New image \u2014 uploaded when you tap Save.'
                                      : 'Tap the image to replace it.',
                                  style: TextStyle(fontSize: 12, color: p.textSecondary),
                                ),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: AppPalette.error),
                                onPressed: _submitting ? null : _removeImage,
                                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                label: const Text('Remove'),
                              ),
                            ],
                          ),
                        if (_isEdit) ...[
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Discontinued'),
                            subtitle: Text(
                                'When off, stock status is calculated automatically from quantity vs. minimum stock level.',
                                style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                            value: _discontinued,
                            onChanged:
                                _submitting ? null : (v) => setState(() => _discontinued = v),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: Text(_submitting
                              ? (_pendingFile != null ? 'Uploading image\u2026' : 'Saving\u2026')
                              : 'Save'),
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

/// Tap-to-upload area: shows the newly picked image, else the saved one,
/// else a prompt.
class _ImageBox extends StatelessWidget {
  const _ImageBox({
    required this.bytes,
    required this.url,
    required this.uploading,
    required this.onTap,
  });

  final Uint8List? bytes;
  final String url;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final Widget content;
    if (bytes != null) {
      content = Image.memory(bytes!, fit: BoxFit.contain);
    } else if (url.isNotEmpty) {
      content = Image.network(url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.broken_image_outlined, color: p.textSecondary, size: 36));
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_upload_outlined, size: 32, color: p.textSecondary),
          const SizedBox(height: 4),
          const Text('Tap to upload an image', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('JPG, PNG or WebP, up to 5 MB',
              style: TextStyle(fontSize: 12, color: p.textSecondary)),
        ],
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: p.dark ? const Color(0xFF1E3336) : const Color(0xFFEEF4F6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.divider, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(child: content),
            if (uploading)
              const ColoredBox(
                color: Color(0x73000000),
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }
}
