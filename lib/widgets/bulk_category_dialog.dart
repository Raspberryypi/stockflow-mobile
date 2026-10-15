import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/theme/palette.dart';
import 'app_alert.dart';

Future<void> showBulkCategoryDialog(
  BuildContext context, {
  required int count,
  required List<Map<String, dynamic>> categories,
  required Future<void> Function(String categoryId) onConfirm,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _BulkCategoryDialog(count: count, categories: categories, onConfirm: onConfirm),
  );
}

class _BulkCategoryDialog extends StatefulWidget {
  const _BulkCategoryDialog({
    required this.count,
    required this.categories,
    required this.onConfirm,
  });

  final int count;
  final List<Map<String, dynamic>> categories;
  final Future<void> Function(String categoryId) onConfirm;

  @override
  State<_BulkCategoryDialog> createState() => _BulkCategoryDialogState();
}

class _BulkCategoryDialogState extends State<_BulkCategoryDialog> {
  String? _target;
  bool _submitting = false;
  String _error = '';

  Future<void> _confirm() async {
    final target = _target;
    if (target == null || target.isEmpty) {
      setState(() => _error = 'Please choose a category');
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await widget.onConfirm(target);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(e, 'Failed to reassign products');
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AlertDialog(
      title: Text('Move ${widget.count} product(s)',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose the category to move the selected products into.',
                style: TextStyle(color: p.textSecondary)),
            const SizedBox(height: 14),
            if (_error.isNotEmpty) AppAlert(_error),
            DropdownButtonFormField<String>(
              initialValue: _target,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in widget.categories)
                  DropdownMenuItem<String>(
                    value: '${c['_id']}',
                    child: Text('${c['name'] ?? ''}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _submitting ? null : (v) => setState(() => _target = v),
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
          child: Text(_submitting ? 'Moving…' : 'Move products'),
        ),
      ],
    );
  }
}
