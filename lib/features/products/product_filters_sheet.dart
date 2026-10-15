import 'package:flutter/material.dart';

const kProductStatuses = ['In Stock', 'Low Stock', 'Out of Stock', 'Discontinued'];

class ProductFilterValues {
  const ProductFilterValues({this.category = '', this.status = '', this.supplier = ''});
  final String category;
  final String status;
  final String supplier;

  int get activeCount =>
      (category.isNotEmpty ? 1 : 0) + (status.isNotEmpty ? 1 : 0) + (supplier.isNotEmpty ? 1 : 0);
}

Future<ProductFilterValues?> showProductFiltersSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> categories,
  required ProductFilterValues current,
}) {
  return showModalBottomSheet<ProductFilterValues>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FiltersSheet(categories: categories, current: current),
  );
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.categories, required this.current});
  final List<Map<String, dynamic>> categories;
  final ProductFilterValues current;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late String _category = widget.current.category;
  late String _status = widget.current.status;
  late final TextEditingController _supplier =
      TextEditingController(text: widget.current.supplier);

  @override
  void dispose() {
    _supplier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryIds = widget.categories.map((c) => '${c['_id']}').toSet();
    final safeCategory = categoryIds.contains(_category) ? _category : '';

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filter products',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey('cat-$safeCategory'),
              initialValue: safeCategory,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All categories')),
                for (final c in widget.categories)
                  DropdownMenuItem(
                    value: '${c['_id']}',
                    child: Text('${c['name'] ?? ''}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _category = v ?? ''),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: ValueKey('status-$_status'),
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All statuses')),
                for (final s in kProductStatuses) DropdownMenuItem(value: s, child: Text(s)),
              ],
              onChanged: (v) => setState(() => _status = v ?? ''),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _supplier,
              decoration: const InputDecoration(labelText: 'Supplier'),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(const ProductFilterValues()),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(ProductFilterValues(
                      category: safeCategory,
                      status: _status,
                      supplier: _supplier.text.trim(),
                    )),
                    child: const Text('Apply'),
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
