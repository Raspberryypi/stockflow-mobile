import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/format.dart';
import '../../services/product_service.dart';
import '../../widgets/product_thumb.dart';
import '../../widgets/status_chip.dart';

Future<Map<String, dynamic>?> showProductPicker(BuildContext context) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _ProductPickerSheet(),
  );
}

class _ProductPickerSheet extends StatefulWidget {
  const _ProductPickerSheet();

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;
  bool _failed = false;
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value.trim()));
  }

  Future<void> _search(String q) async {
    final id = ++_reqId;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final res = await ProductService.getProducts({
        'limit': 25,
        'sortBy': 'name',
        'sortOrder': 'asc',
        if (q.isNotEmpty) 'search': q,
      });
      if (!mounted || id != _reqId) return;
      setState(() => _results = asMapList(res['data']));
    } catch (_) {
      if (mounted && id == _reqId) {
        setState(() {
          _results = [];
          _failed = true;
        });
      }
    } finally {
      if (mounted && id == _reqId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final height = MediaQuery.of(context).size.height * 0.8;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Search by name or SKU\u2026',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _controller.clear();
                            _onChanged('');
                          },
                        ),
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _results.isEmpty
                  ? Center(
                      child: Text(
                        _loading
                            ? ''
                            : (_failed ? 'Could not load products.' : 'No products found'),
                        style: TextStyle(color: p.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final product = _results[i];
                        return ListTile(
                          leading: ProductThumb(url: product['imageUrl']?.toString(), size: 40),
                          title: Text('${product['name'] ?? ''}',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                              '${product['sku'] ?? ''}  \u00B7  Qty ${formatInt(toNum(product['quantity']))}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: StatusChip('${product['status'] ?? ''}'),
                          onTap: () => Navigator.of(context).pop(product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
