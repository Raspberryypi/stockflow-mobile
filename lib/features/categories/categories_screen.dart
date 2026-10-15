import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/format.dart';
import '../../core/utils/print_table.dart';
import '../../providers/auth_provider.dart';
import '../../services/category_service.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/list_widgets.dart';
import '../../widgets/page_container.dart';
import '../../widgets/permanent_delete_dialog.dart';
import '../../widgets/print_table_button.dart';

int _extractProductCount(String message) {
  final match = RegExp(r'(\d+) product').firstMatch(message);
  return match == null ? 0 : int.parse(match.group(1)!);
}

/// Port of pages/categories/CategoryList.jsx.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _searchCtl = TextEditingController();
  bool _archived = false;
  bool _sortDesc = false; // by name
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final res = await CategoryService.getCategories(_archived ? {'archived': true} : null);
      if (mounted) setState(() => _categories = asMapList(res['data']));
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, 'Failed to load categories.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Small, fully-fetched list: search and sort on the device.
  List<Map<String, dynamic>> get _visible {
    final term = _searchCtl.text.trim().toLowerCase();
    final list = term.isEmpty
        ? [..._categories]
        : _categories
            .where((c) =>
                '${c['name'] ?? ''}'.toLowerCase().contains(term) ||
                '${c['description'] ?? ''}'.toLowerCase().contains(term))
            .toList();
    list.sort((a, b) {
      final r = '${a['name'] ?? ''}'.toLowerCase().compareTo('${b['name'] ?? ''}'.toLowerCase());
      return _sortDesc ? -r : r;
    });
    return list;
  }

  void _setArchived(bool v) {
    if (v == _archived) return;
    setState(() => _archived = v);
    _load();
  }

  Future<void> _openForm([Map<String, dynamic>? category]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryFormDialog(category: category),
    );
    if (saved == true && mounted) {
      showSnack(context, category == null ? 'Category created' : 'Category updated');
      _load();
    }
  }

  // Archives (soft delete). If products still use the category the server
  // answers 409 and we offer to move those products elsewhere first.
  Future<void> _archive(Map<String, dynamic> category) {
    return showConfirmDialog(
      context,
      title: 'Archive category?',
      message:
          '"${category['name']}" will be hidden from the category list and product forms. You can restore it any time from the Archived tab.',
      confirmLabel: 'Archive',
      destructive: false,
      onConfirm: () async {
        try {
          await CategoryService.deleteCategory('${category['_id']}');
          if (!mounted) return;
          showSnack(context, 'Category archived. You can restore it from the Archived tab.');
          _load();
        } catch (e) {
          if (!mounted) return;
          final message = apiErrorMessage(e, '');
          if (e is DioException && e.response?.statusCode == 409) {
            // Open the reassign dialog once the confirm dialog has closed.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _reassign(category, _extractProductCount(message));
            });
          } else {
            showSnack(context, message.isEmpty ? 'Failed to archive category' : message);
          }
        }
      },
    );
  }

  Future<void> _reassign(Map<String, dynamic> category, int productCount) async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => _ReassignCategoryDialog(
        category: category,
        productCount: productCount,
        categories: _categories,
      ),
    );
    if (done == true && mounted) {
      showSnack(context, 'Products reassigned and category archived');
      _load();
    }
  }

  Future<void> _restore(Map<String, dynamic> category) async {
    try {
      final res = await CategoryService.restoreCategory('${category['_id']}');
      if (!mounted) return;
      showSnack(context, '${res['message'] ?? 'Category restored'}');
      _load();
    } catch (e) {
      // e.g. an active category now has the same name
      if (mounted) showSnack(context, apiErrorMessage(e, 'Failed to restore category'));
    }
  }

  Future<void> _deletePermanently(Map<String, dynamic> category) {
    return showPermanentDeleteDialog(
      context,
      title: 'Delete category permanently?',
      itemName: '${category['name']}',
      description:
          "A category that any product (archived ones included) still belongs to can't be deleted permanently and stays archived instead.",
      onConfirm: () async {
        try {
          final res = await CategoryService.permanentlyDeleteCategory('${category['_id']}');
          if (!mounted) return;
          showSnack(context, '${res['message'] ?? 'Category deleted'}');
          _load();
        } catch (e) {
          if (mounted) showSnack(context, apiErrorMessage(e, 'Failed to delete category permanently'));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;
    final visible = _visible;
    final search = _searchCtl.text.trim();
    Object? printDate(Map<String, dynamic> c) => _archived ? c['deletedAt'] : c['createdAt'];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: (isAdmin && !_archived)
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Category'),
            )
          : null,
      body: PageContainer(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: isAdmin ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ArchiveViewToggle(archived: _archived, onChanged: _setArchived),
                      ) : null,
                    ),
                  ),
                  IconButton(
                    tooltip: _sortDesc ? 'Sort A–Z' : 'Sort Z–A',
                    onPressed: () => setState(() => _sortDesc = !_sortDesc),
                    icon: Icon(_sortDesc ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
                  ),
                  PrintTableButton<Map<String, dynamic>>(
                    title: _archived ? 'Archived Categories' : 'Categories',
                    subtitle: search.isEmpty ? '' : 'Search: "$search"',
                    columns: [
                      PrintColumn('Name', (c) => c['name']),
                      PrintColumn('Description', (c) => c['description']),
                      PrintColumn(_archived ? 'Archived on' : 'Created',
                          (c) => printDate(c) == null ? '' : formatDate(printDate(c))),
                    ],
                    getRows: (_, _) async => visible,
                    dateOf: printDate,
                    dateLabel: _archived ? 'archived' : 'created',
                    disabled: _loading,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: ListSearchField(
                controller: _searchCtl,
                hint: 'Search categories…',
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _buildList(visible, isAdmin, search),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> visible, bool isAdmin, String search) {
    if (_loading && _categories.isEmpty) return const ListStatus.loading();
    if (_error.isNotEmpty) return ListStatus.error(_error, onRetry: _load);
    if (visible.isEmpty) {
      return ListStatus.empty(
        emptyIcon: Icons.category_outlined,
        emptyText: search.isNotEmpty
            ? 'No categories match your search.'
            : _archived
                ? 'No archived categories.'
                : 'No categories yet.',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final c = visible[i];
        final desc = '${c['description'] ?? ''}';
        return ListRowCard(
          title: '${c['name'] ?? ''}',
          lines: [
            desc.isEmpty ? '—' : desc,
            if (_archived) 'Archived on ${formatDate(c['deletedAt'])}',
          ],
          onTap: (isAdmin && !_archived) ? () => _openForm(c) : null,
          trailing: isAdmin ? _menu(c) : null,
        );
      },
    );
  }

  Widget _menu(Map<String, dynamic> c) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: (action) {
        switch (action) {
          case 'edit':
            _openForm(c);
          case 'archive':
            _archive(c);
          case 'restore':
            _restore(c);
          case 'delete':
            _deletePermanently(c);
        }
      },
      itemBuilder: (_) => _archived
          ? const [
              PopupMenuItem(
                  value: 'restore',
                  child: ListTile(leading: Icon(Icons.restore_from_trash_rounded), title: Text('Restore'))),
              PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                      leading: Icon(Icons.delete_forever_rounded, color: AppPalette.error),
                      title: Text('Delete permanently'))),
            ]
          : const [
              PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_rounded), title: Text('Edit'))),
              PopupMenuItem(
                  value: 'archive',
                  child: ListTile(
                      leading: Icon(Icons.archive_outlined, color: AppPalette.warningDark),
                      title: Text('Archive'))),
            ],
    );
  }
}

/// Port of CategoryFormDialog.jsx. Pops `true` once saved.
class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({this.category});
  final Map<String, dynamic>? category;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final _name = TextEditingController(text: '${widget.category?['name'] ?? ''}');
  late final _description = TextEditingController(text: '${widget.category?['description'] ?? ''}');
  String _error = '';
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Category name is required');
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
    });
    final form = {'name': _name.text, 'description': _description.text};
    try {
      if (widget.category == null) {
        await CategoryService.createCategory(form);
      } else {
        await CategoryService.updateCategory('${widget.category!['_id']}', form);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(e, 'Failed to save category');
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? 'Add Category' : 'Edit Category',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error.isNotEmpty) AppAlert(_error),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description'),
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
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}

/// Port of ReassignCategoryDialog.jsx. Pops `true` once products were moved
/// and the category archived.
class _ReassignCategoryDialog extends StatefulWidget {
  const _ReassignCategoryDialog({
    required this.category,
    required this.productCount,
    required this.categories,
  });
  final Map<String, dynamic> category;
  final int productCount;
  final List<Map<String, dynamic>> categories;

  @override
  State<_ReassignCategoryDialog> createState() => _ReassignCategoryDialogState();
}

class _ReassignCategoryDialogState extends State<_ReassignCategoryDialog> {
  String? _target;
  bool _submitting = false;
  String _error = '';

  Future<void> _confirm() async {
    if (_target == null) {
      setState(() => _error = 'Please choose a category to move these products to');
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await CategoryService.deleteCategory('${widget.category['_id']}', reassignTo: _target);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(e, 'Failed to reassign and delete');
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final others = widget.categories.where((c) => c['_id'] != widget.category['_id']).toList();
    return AlertDialog(
      title: const Text('Category still in use',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.productCount} product(s) are still assigned to "${widget.category['name']}". Choose another category to move them to before archiving.',
              style: TextStyle(color: p.textSecondary),
            ),
            const SizedBox(height: 16),
            if (_error.isNotEmpty) AppAlert(_error),
            DropdownButtonFormField<String>(
              initialValue: _target,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Move products to'),
              items: [
                for (final c in others)
                  DropdownMenuItem(value: '${c['_id']}', child: Text('${c['name']}')),
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
          style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
          onPressed: _submitting ? null : _confirm,
          child: Text(_submitting ? 'Please wait…' : 'Reassign & Archive'),
        ),
      ],
    );
  }
}
