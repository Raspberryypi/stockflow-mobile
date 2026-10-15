import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/format.dart';
import '../../core/utils/print_table.dart';
import '../../providers/auth_provider.dart';
import '../../services/location_service.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/list_widgets.dart';
import '../../widgets/page_container.dart';
import '../../widgets/permanent_delete_dialog.dart';
import '../../widgets/print_table_button.dart';

/// Port of pages/locations/LocationList.jsx.
class LocationsScreen extends StatefulWidget {
  const LocationsScreen({super.key});

  @override
  State<LocationsScreen> createState() => _LocationsScreenState();
}

class _LocationsScreenState extends State<LocationsScreen> {
  final _searchCtl = TextEditingController();
  bool _archived = false;
  List<Map<String, dynamic>> _locations = [];
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
      final res = await LocationService.getLocations(_archived ? {'archived': true} : null);
      if (mounted) setState(() => _locations = asMapList(res['data']));
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, 'Failed to load locations.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _visible {
    final term = _searchCtl.text.trim().toLowerCase();
    if (term.isEmpty) return _locations;
    return _locations
        .where((l) =>
            '${l['name'] ?? ''}'.toLowerCase().contains(term) ||
            '${l['code'] ?? ''}'.toLowerCase().contains(term) ||
            '${l['description'] ?? ''}'.toLowerCase().contains(term))
        .toList();
  }

  void _setArchived(bool v) {
    if (v == _archived) return;
    setState(() => _archived = v);
    _load();
  }

  Future<void> _openForm([Map<String, dynamic>? location]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _LocationFormDialog(location: location),
    );
    if (saved == true && mounted) {
      showSnack(context, location == null ? 'Location created' : 'Location updated');
      _load();
    }
  }

  Future<void> _archive(Map<String, dynamic> location) {
    return showConfirmDialog(
      context,
      title: 'Archive location?',
      message:
          '"${location['name']}" will be hidden from the location list and stock forms. Locations that still hold stock can\'t be archived. You can restore it any time from the Archived tab.',
      confirmLabel: 'Archive',
      destructive: false,
      onConfirm: () async {
        try {
          await LocationService.deleteLocation('${location['_id']}');
          if (!mounted) return;
          showSnack(context, 'Location archived. You can restore it from the Archived tab.');
          _load();
        } catch (e) {
          // e.g. "still holds N unit(s)" from the backend
          if (mounted) showSnack(context, apiErrorMessage(e, 'Failed to archive location'));
        }
      },
    );
  }

  Future<void> _restore(Map<String, dynamic> location) async {
    try {
      final res = await LocationService.restoreLocation('${location['_id']}');
      if (!mounted) return;
      showSnack(context, '${res['message'] ?? 'Location restored'}');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, apiErrorMessage(e, 'Failed to restore location'));
    }
  }

  Future<void> _deletePermanently(Map<String, dynamic> location) {
    return showPermanentDeleteDialog(
      context,
      title: 'Delete location permanently?',
      itemName: '${location['name']}',
      description:
          "A location that appears in stock transactions or purchase orders can't be deleted permanently and stays archived instead.",
      onConfirm: () async {
        try {
          final res = await LocationService.permanentlyDeleteLocation('${location['_id']}');
          if (!mounted) return;
          showSnack(context, '${res['message'] ?? 'Location deleted'}');
          _load();
        } catch (e) {
          if (mounted) showSnack(context, apiErrorMessage(e, 'Failed to delete location permanently'));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;
    final visible = _visible;
    final search = _searchCtl.text.trim();
    Object? printDate(Map<String, dynamic> l) => _archived ? l['deletedAt'] : l['createdAt'];

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: (isAdmin && !_archived)
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Location'),
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
                  PrintTableButton<Map<String, dynamic>>(
                    title: _archived ? 'Archived Locations' : 'Locations',
                    subtitle: search.isEmpty ? '' : 'Search: "$search"',
                    columns: [
                      PrintColumn('Name', (l) => l['name']),
                      PrintColumn('Code', (l) => l['code']),
                      PrintColumn('Description', (l) => l['description']),
                      if (!_archived) ...[
                        PrintColumn('Products', (l) => l['productCount'], alignRight: true),
                        PrintColumn('Units held', (l) => l['totalUnits'], alignRight: true),
                      ],
                      PrintColumn(_archived ? 'Archived on' : 'Created',
                          (l) => printDate(l) == null ? '' : formatDate(printDate(l))),
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
                hint: 'Search by name, code or description…',
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
    if (_loading && _locations.isEmpty) return const ListStatus.loading();
    if (_error.isNotEmpty) return ListStatus.error(_error, onRetry: _load);
    if (visible.isEmpty) {
      return ListStatus.empty(
        emptyIcon: Icons.place_outlined,
        emptyText: search.isNotEmpty
            ? 'No locations match your search.'
            : _archived
                ? 'No archived locations.'
                : 'No locations yet.',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final l = visible[i];
        final code = '${l['code'] ?? ''}';
        final desc = '${l['description'] ?? ''}';
        return ListRowCard(
          title: '${l['name'] ?? ''}',
          titleTrailing: code.isEmpty ? null : SmallChip(code, outlined: true),
          lines: [
            if (desc.isNotEmpty) desc,
            _archived
                ? 'Archived on ${formatDate(l['deletedAt'])}'
                : '${formatInt(toNum(l['productCount']))} product(s) · ${formatInt(toNum(l['totalUnits']))} unit(s) held',
          ],
          onTap: (isAdmin && !_archived) ? () => _openForm(l) : null,
          trailing: isAdmin ? _menu(l) : null,
        );
      },
    );
  }

  Widget _menu(Map<String, dynamic> l) {
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      onSelected: (action) {
        switch (action) {
          case 'edit':
            _openForm(l);
          case 'archive':
            _archive(l);
          case 'restore':
            _restore(l);
          case 'delete':
            _deletePermanently(l);
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

/// Port of LocationFormDialog.jsx. Pops `true` once saved.
class _LocationFormDialog extends StatefulWidget {
  const _LocationFormDialog({this.location});
  final Map<String, dynamic>? location;

  @override
  State<_LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<_LocationFormDialog> {
  late final _name = TextEditingController(text: '${widget.location?['name'] ?? ''}');
  late final _code = TextEditingController(text: '${widget.location?['code'] ?? ''}');
  late final _description = TextEditingController(text: '${widget.location?['description'] ?? ''}');
  String _error = '';
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Location name is required');
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
    });
    final form = {'name': _name.text, 'code': _code.text, 'description': _description.text};
    try {
      if (widget.location == null) {
        await LocationService.createLocation(form);
      } else {
        await LocationService.updateLocation('${widget.location!['_id']}', form);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = apiErrorMessage(e, 'Failed to save location');
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.location == null ? 'Add Location' : 'Edit Location',
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
              decoration: const InputDecoration(labelText: 'Name *', hintText: 'e.g. Main Warehouse'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Code', hintText: 'e.g. WH-01'),
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
