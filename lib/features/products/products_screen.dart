import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/csv.dart';
import '../../core/utils/file_export.dart';
import '../../core/utils/format.dart';
import '../../core/utils/print_table.dart';
import '../../providers/auth_provider.dart';
import '../../services/category_service.dart';
import '../../services/product_service.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/bulk_category_dialog.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/page_container.dart';
import '../../widgets/permanent_delete_dialog.dart';
import '../../widgets/print_table_button.dart';
import 'product_details_page.dart';
import 'product_filters_sheet.dart';
import 'product_form_page.dart';
import 'product_tile.dart';

const _pageSize = 10;

/// A sort choice = field + direction (the web sorts by clicking column headers).
class _SortOption {
  const _SortOption(this.label, this.by, this.order);
  final String label;
  final String by;
  final String order;
}

const _sortOptions = [
  _SortOption('Newest first', 'createdAt', 'desc'),
  _SortOption('Oldest first', 'createdAt', 'asc'),
  _SortOption('Name A\u2013Z', 'name', 'asc'),
  _SortOption('Name Z\u2013A', 'name', 'desc'),
  _SortOption('Price: low to high', 'price', 'asc'),
  _SortOption('Price: high to low', 'price', 'desc'),
  _SortOption('Quantity: low to high', 'quantity', 'asc'),
  _SortOption('Quantity: high to low', 'quantity', 'desc'),
];

/// Port of pages/products/ProductList.jsx for mobile.
///
/// Deep links (from the notification bell / global search):
///   /products?status=Low+Stock  -> opens with that status filter
///   /products?view=<id>         -> opens that product's details page
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, this.initialStatus, this.viewId});
  final String? initialStatus;
  final String? viewId;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _scroll = ScrollController();
  final _searchCtl = TextEditingController();
  Timer? _debounce;

  // Filters / sort (same fields as useProducts.js).
  String _search = '';
  String _category = '';
  String _status = '';
  String _supplier = '';
  String _sortBy = 'createdAt';
  String _sortOrder = 'desc';
  bool _archived = false;

  // Data.
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  int _page = 1;
  int _totalPages = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String _error = '';
  int _reqId = 0; // ignore responses from superseded requests

  // Bulk selection (admin, normal view only).
  final Set<String> _selected = {};

  String? _openingViewId;

  bool _exporting = false;
  bool _importing = false;

  bool get _isAdmin => context.read<AuthProvider>().user?.isAdmin ?? false;
  bool get _selecting => _selected.isNotEmpty;
  int get _filterCount =>
      ProductFilterValues(category: _category, status: _status, supplier: _supplier).activeCount;
  bool get _hasAnyFilter => _search.isNotEmpty || _filterCount > 0;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus ?? '';
    _scroll.addListener(_onScroll);
    _loadCategories();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOpenView());
  }

  @override
  void didUpdateWidget(covariant ProductsScreen old) {
    super.didUpdateWidget(old);
    final status = widget.initialStatus;
    if (status != null && status != old.initialStatus && status != _status) {
      setState(() => _status = status);
      _load();
    }
    if (widget.viewId != old.viewId) _maybeOpenView();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  // ── Loading ────────────────────────────────────────────────────

  Future<void> _loadCategories() async {
    try {
      final res = await CategoryService.getCategories();
      if (mounted) setState(() => _categories = asMapList(res['data']));
    } catch (_) {
      if (mounted) setState(() => _categories = []);
    }
  }

  Map<String, dynamic> _params(int page) {
    final params = <String, dynamic>{
      'sortBy': _sortBy,
      'sortOrder': _sortOrder,
      'page': page,
      'limit': _pageSize,
    };
    if (_search.isNotEmpty) params['search'] = _search;
    if (_category.isNotEmpty) params['category'] = _category;
    if (_status.isNotEmpty) params['status'] = _status;
    if (_supplier.isNotEmpty) params['supplier'] = _supplier;
    if (_archived) params['archived'] = 'true';
    return params;
  }

  /// Loads page 1 and replaces the list (used for every filter/sort change).
  Future<void> _load() async {
    final id = ++_reqId;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final res = await ProductService.getProducts(_params(1));
      if (!mounted || id != _reqId) return;
      final pg = asMap(res['pagination']);
      final list = asMapList(res['data']);
      final totalPages = toNum(pg['totalPages']).toInt();
      setState(() {
        _products = list;
        _page = 1;
        _totalPages = totalPages < 1 ? 1 : totalPages;
        _total = pg['total'] == null ? list.length : toNum(pg['total']).toInt();
        // Selection is a subset of what's on screen: reset it with the list.
        _selected.clear();
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      setState(() => _error = apiErrorMessage(e, 'Failed to load products.'));
    } finally {
      if (mounted && id == _reqId) setState(() => _loading = false);
    }
  }

  /// Appends the next page (infinite scroll replaces the web's pagination bar).
  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _totalPages) return;
    final id = _reqId;
    setState(() => _loadingMore = true);
    try {
      final res = await ProductService.getProducts(_params(_page + 1));
      if (!mounted || id != _reqId) return;
      setState(() {
        _products = [..._products, ...asMapList(res['data'])];
        _page += 1;
      });
    } catch (e) {
      if (mounted && id == _reqId) _snack(apiErrorMessage(e, 'Failed to load more products.'));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) _loadMore();
  }

  // ── Small helpers ──────────────────────────────────────────────

  void _snack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onSearchChanged(String value) {
    setState(() {}); // refresh the clear (x) button
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
      _category = '';
      _status = '';
      _supplier = '';
    });
    _load();
  }

  Future<void> _openFilters() async {
    final result = await showProductFiltersSheet(
      context,
      categories: _categories,
      current: ProductFilterValues(category: _category, status: _status, supplier: _supplier),
    );
    if (result == null || !mounted) return;
    setState(() {
      _category = result.category;
      _status = result.status;
      _supplier = result.supplier;
    });
    _load();
  }

  void _setSort(_SortOption option) {
    setState(() {
      _sortBy = option.by;
      _sortOrder = option.order;
    });
    _load();
  }

  /// Switching tabs changes the query (archived defaults to newest-archived first).
  void _setArchived(bool archived) {
    if (archived == _archived) return;
    setState(() {
      _archived = archived;
      _sortBy = archived ? 'deletedAt' : 'createdAt';
      _sortOrder = 'desc';
      _selected.clear();
    });
    _load();
  }

  // ── Navigation: details / add / edit ───────────────────────────

  void _maybeOpenView() {
    final id = widget.viewId;
    if (!mounted || id == null || id.isEmpty || id == _openingViewId) return;
    _openingViewId = id;
    _openDetails(id, fromLink: true);
  }

  Future<void> _openDetails(String id, {bool fromLink = false}) async {
    final isAdmin = _isAdmin;
    final result = await Navigator.of(context, rootNavigator: true).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ProductDetailsPage(productId: id, canEdit: isAdmin),
      ),
    );
    if (!mounted) return;
    if (fromLink) {
      // Drop ?view= from the URL so the same product can be opened again later.
      _openingViewId = null;
      context.go('/products');
    }
    final editId = result?['_id']?.toString();
    if (editId != null) _openForm(editId);
  }

  Future<void> _openForm([String? productId]) async {
    final saved = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormPage(productId: productId, categories: _categories),
      ),
    );
    if (saved == true && mounted) {
      _snack(productId == null ? 'Product created successfully' : 'Product updated successfully');
      _load();
    }
  }

  // ── Row actions ────────────────────────────────────────────────

  void _onMenu(Map<String, dynamic> product, ProductMenuAction action) {
    switch (action) {
      case ProductMenuAction.edit:
        _openForm('${product['_id']}');
      case ProductMenuAction.archive:
        _archive(product);
      case ProductMenuAction.restore:
        _restore(product);
      case ProductMenuAction.deletePermanently:
        _deletePermanently(product);
    }
  }

  Future<void> _archive(Map<String, dynamic> product) {
    return showConfirmDialog(
      context,
      title: 'Archive product?',
      message:
          '"${product['name']}" will be hidden from the product list, alerts and reports. Its history is kept, and you can restore it any time from the Archived tab.',
      confirmLabel: 'Archive',
      destructive: false,
      onConfirm: () async {
        try {
          await ProductService.deleteProduct('${product['_id']}');
          _snack('Product archived. You can restore it from the Archived tab.');
          _load();
        } catch (e) {
          _snack(apiErrorMessage(e, 'Failed to archive product'));
        }
      },
    );
  }

  Future<void> _restore(Map<String, dynamic> product) async {
    try {
      final res = await ProductService.restoreProduct('${product['_id']}');
      _snack('${res['message'] ?? 'Product restored'}');
      _load();
    } catch (e) {
      // e.g. SKU now used by an active product, or its category is archived
      _snack(apiErrorMessage(e, 'Failed to restore product'));
    }
  }

  Future<void> _deletePermanently(Map<String, dynamic> product) {
    return showPermanentDeleteDialog(
      context,
      title: 'Delete product permanently?',
      itemName: '${product['name']}',
      description:
          "Its image and stock-location records are removed too. Products that appear in transactions or purchase orders can't be deleted permanently and stay archived instead.",
      onConfirm: () async {
        try {
          final res = await ProductService.permanentlyDeleteProduct('${product['_id']}');
          _snack('${res['message'] ?? 'Product deleted'}');
          _load();
        } catch (e) {
          // e.g. blocked because the product has transaction history
          _snack(apiErrorMessage(e, 'Failed to delete product permanently'));
        }
      },
    );
  }

  // ── Selection / bulk actions ───────────────────────────────────

  void _toggleSelect(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _selectAllLoaded() {
    setState(() => _selected
      ..clear()
      ..addAll(_products.map((p) => '${p['_id']}')));
  }

  Future<void> _bulkArchive() {
    final ids = _selected.toList();
    return showConfirmDialog(
      context,
      title: 'Archive ${ids.length} product(s)?',
      message:
          'The selected products will be hidden from the product list, alerts and reports. Their history is kept, and you can restore them from the Archived tab.',
      confirmLabel: 'Archive all',
      destructive: false,
      onConfirm: () async {
        try {
          final res = await ProductService.bulkArchiveProducts(ids);
          _snack('${res['message'] ?? 'Products archived'}');
          _load();
        } catch (e) {
          _snack(apiErrorMessage(e, 'Failed to archive selected products'));
        }
      },
    );
  }

  Future<void> _bulkMove() {
    final ids = _selected.toList();
    return showBulkCategoryDialog(
      context,
      count: ids.length,
      categories: _categories,
      onConfirm: (categoryId) async {
        final res = await ProductService.bulkReassignCategory(ids, categoryId);
        _snack('${res['message'] ?? 'Products moved'}');
        _load();
      },
    );
  }

  // ── Export / import / print (ProductList.jsx toolbar) ──────────

  /// Every product matching the current filters, not just the loaded pages.
  Future<List<Map<String, dynamic>>> _fetchAllMatching(int limit) async {
    final params = _params(1)
      ..remove('page')
      ..['limit'] = limit;
    final res = await ProductService.getProducts(params);
    return asMapList(res['data']);
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final rows = await _fetchAllMatching(1000);
      final saved = await saveOrShareFile(
        fileName: datedFileName('inventory-export', 'csv'),
        bytes: csvBytes(productsToCsv(rows)),
        mimeType: 'text/csv',
      );
      if (saved) _snack('Exported ${rows.length} product(s) to CSV.');
    } catch (_) {
      _snack('Failed to export products');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _import() async {
    PlatformFile? file;
    try {
      file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['csv']);
    } catch (_) {
      _snack('Could not open the file picker.');
      return;
    }
    if (file == null) return;

    setState(() => _importing = true);
    try {
      final text = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      final rows = parseProductsCsv(text);
      final res = await ProductService.bulkImportProducts(rows);
      final data = asMap(res['data']);
      final created = toNum(data['createdCount']).toInt();
      final errors = asMapList(data['errors']);
      if (errors.isNotEmpty) {
        _snack('Imported $created product(s). ${errors.length} row(s) failed '
            '(e.g. row ${errors.first['row']}: ${errors.first['message']}).');
      } else {
        _snack('Imported $created product(s) successfully.');
      }
      _load();
    } on FormatException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack(apiErrorMessage(e, 'Failed to import CSV'));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _print() {
    final categoryName = _category.isEmpty
        ? ''
        : '${_categories.firstWhere((c) => '${c['_id']}' == _category, orElse: () => {})['name'] ?? ''}';
    Object? printDate(Map<String, dynamic> p) => _archived ? p['deletedAt'] : p['createdAt'];
    startPrintTable<Map<String, dynamic>>(
      context,
      title: _archived ? 'Archived Products' : 'Products',
      subtitle: [
        if (_archived) 'Archived products',
        if (_search.isNotEmpty) 'Search: "$_search"',
        if (_category.isNotEmpty) 'Category: $categoryName',
        if (_status.isNotEmpty) 'Status: $_status',
        if (_supplier.isNotEmpty) 'Supplier: $_supplier',
      ].join('  |  '),
      columns: [
        PrintColumn('Name', (p) => p['name']),
        PrintColumn('SKU', (p) => p['sku']),
        PrintColumn('Category', (p) => asMap(p['category'])['name']),
        PrintColumn('Price', (p) => formatCurrency(toNum(p['price'])), alignRight: true),
        PrintColumn('Qty', (p) => p['quantity'], alignRight: true),
        PrintColumn('Min', (p) => p['minimumStockLevel'], alignRight: true),
        PrintColumn('Status', (p) => p['status']),
        PrintColumn('Supplier', (p) => p['supplier']),
        PrintColumn(_archived ? 'Archived on' : 'Created',
            (p) => printDate(p) == null ? '' : formatDate(printDate(p))),
      ],
      getRows: (_, _) => _fetchAllMatching(5000),
      dateOf: printDate,
      dateLabel: _archived ? 'archived' : 'created',
      landscape: true,
    );
  }

  // ── UI ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: (isAdmin && !_archived && !_selecting)
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Product'),
            )
          : null,
      body: PageContainer(
        maxWidth: 900,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Products',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      if (isAdmin)
                        SegmentedButton<bool>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(visualDensity: VisualDensity.compact),
                          segments: const [
                            ButtonSegment(value: false, label: Text('Active')),
                            ButtonSegment(
                              value: true,
                              icon: Icon(Icons.archive_outlined, size: 16),
                              label: Text('Archived'),
                            ),
                          ],
                          selected: {_archived},
                          onSelectionChanged: (s) => _setArchived(s.first),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtl,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: 'Search by name or SKU\u2026',
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
                      PopupMenuButton<_SortOption>(
                        tooltip: 'Sort',
                        icon: const Icon(Icons.sort_rounded),
                        onSelected: _setSort,
                        itemBuilder: (_) => [
                          for (final o in _sortOptions)
                            CheckedPopupMenuItem(
                              value: o,
                              checked: o.by == _sortBy && o.order == _sortOrder,
                              child: Text(o.label),
                            ),
                        ],
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'More actions',
                        icon: (_exporting || _importing)
                            ? const SizedBox(
                                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.more_vert_rounded),
                        enabled: !_exporting && !_importing,
                        onSelected: (a) {
                          switch (a) {
                            case 'import':
                              _import();
                            case 'export':
                              _export();
                            case 'print':
                              _print();
                          }
                        },
                        itemBuilder: (_) => [
                          if (isAdmin && !_archived)
                            const PopupMenuItem(
                              value: 'import',
                              child: ListTile(
                                  leading: Icon(Icons.file_upload_outlined), title: Text('Import CSV')),
                            ),
                          const PopupMenuItem(
                            value: 'export',
                            child: ListTile(
                                leading: Icon(Icons.file_download_outlined), title: Text('Export CSV')),
                          ),
                          const PopupMenuItem(
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
                          Text('$_total product${_total == 1 ? '' : 's'}',
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
            if (isAdmin && !_archived && _selecting) _buildSelectionBar(p),
            const SizedBox(height: 4),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _buildList(p, isAdmin),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBar(AppPalette p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: p.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.divider),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Text('${_selected.length} selected',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          TextButton(onPressed: _selectAllLoaded, child: const Text('Select all')),
          TextButton.icon(
            onPressed: _bulkMove,
            icon: const Icon(Icons.drive_file_move_rounded, size: 18),
            label: const Text('Move'),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: AppPalette.warningDark),
            onPressed: _bulkArchive,
            icon: const Icon(Icons.archive_outlined, size: 18),
            label: const Text('Archive'),
          ),
          IconButton(
            tooltip: 'Clear selection',
            onPressed: () => setState(_selected.clear),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildList(AppPalette p, bool isAdmin) {
    const padding = EdgeInsets.fromLTRB(16, 8, 16, 96); // room for the FAB

    if (_loading && _products.isEmpty) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => Container(
          height: 76,
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

    if (_products.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: [
          const SizedBox(height: 56),
          Icon(Icons.inventory_2_outlined, size: 40, color: p.textSecondary.withValues(alpha: 0.6)),
          const SizedBox(height: 8),
          Text(
            _archived ? 'No archived products.' : 'No products match your filters.',
            textAlign: TextAlign.center,
            style: TextStyle(color: p.textSecondary),
          ),
        ],
      );
    }

    final canSelect = isAdmin && !_archived;
    final hasMore = _page < _totalPages;

    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: _products.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i >= _products.length) {
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
        final product = _products[i];
        final id = '${product['_id']}';
        return ProductTile(
          product: product,
          archived: _archived,
          canManage: isAdmin,
          selectionMode: canSelect && _selecting,
          selected: _selected.contains(id),
          onTap: () {
            if (canSelect && _selecting) {
              _toggleSelect(id);
            } else if (!_archived) {
              _openDetails(id);
            }
          },
          onLongPress: () {
            if (canSelect) _toggleSelect(id);
          },
          onMenu: (action) => _onMenu(product, action),
        );
      },
    );
  }
}
