import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/palette.dart';
import '../../services/product_service.dart';
import '../../widgets/status_chip.dart';

const _minChars = 2;

/// Mobile version of GlobalSearch.jsx: full-screen search (the web's inline
/// autocomplete doesn't fit a phone header). Searches name / SKU as you type
/// (300ms debounce) and opens the product on the Products screen.
class GlobalSearchPage extends StatefulWidget {
  const GlobalSearchPage({super.key});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}

class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String _query = '';
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final q = value.trim();
    setState(() => _query = q);
    if (q.length < _minChars) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(q));
  }

  Future<void> _search(String q) async {
    final id = ++_requestId; // ignore stale responses (the `cancelled` flag on the web)
    setState(() => _loading = true);
    try {
      final res = await ProductService.getProducts({'search': q, 'limit': 8});
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = ((res['data'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (_) {
      if (mounted && id == _requestId) setState(() => _results = []);
    } finally {
      if (mounted && id == _requestId) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Search products…',
            hintStyle: TextStyle(color: AppPalette.sidebarText),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _query.length < _minChars
                          ? 'Type at least $_minChars characters'
                          : (_loading ? '' : 'No products found'),
                      style: TextStyle(color: p.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final product = _results[i];
                      return ListTile(
                        title: Text('${product['name'] ?? ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${product['sku'] ?? ''}',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: StatusChip('${product['status'] ?? ''}'),
                        onTap: () {
                          final id = product['_id'];
                          Navigator.of(context).pop();
                          context.go('/products?view=$id');
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
