import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/format.dart';
import '../../core/utils/print_table.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/list_widgets.dart';
import '../../widgets/page_container.dart';
import '../../widgets/permanent_delete_dialog.dart';
import '../../widgets/print_table_button.dart';
import '../../widgets/user_avatar.dart';

class _SortOption {
  const _SortOption(this.label, this.by, this.desc);
  final String label;
  final String by; // name | email | role | date
  final bool desc;
}

const _sortOptions = [
  _SortOption('Newest first', 'date', true),
  _SortOption('Oldest first', 'date', false),
  _SortOption('Name A–Z', 'name', false),
  _SortOption('Name Z–A', 'name', true),
  _SortOption('Email A–Z', 'email', false),
  _SortOption('Role', 'role', false),
];

/// Port of pages/users/UserList.jsx (admin only; the router guards it).
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _searchCtl = TextEditingController();
  bool _archived = false;
  _SortOption _sort = _sortOptions.first;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String _error = '';

  String get _dateKey => _archived ? 'archivedAt' : 'createdAt';
  String get _dateLabel => _archived ? 'Archived on' : 'Joined';

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
      final res = await UserService.getUsers(_archived ? {'archived': true} : null);
      if (mounted) setState(() => _users = asMapList(res['data']));
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, 'Failed to load users.'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // The date column is "Joined" in one view and "Archived on" in the other,
  // so switching views resets to newest-first.
  void _setArchived(bool v) {
    if (v == _archived) return;
    setState(() {
      _archived = v;
      _sort = _sortOptions.first;
    });
    _load();
  }

  List<Map<String, dynamic>> get _visible {
    final term = _searchCtl.text.trim().toLowerCase();
    final list = term.isEmpty
        ? [..._users]
        : _users
            .where((u) =>
                '${u['name'] ?? ''}'.toLowerCase().contains(term) ||
                '${u['email'] ?? ''}'.toLowerCase().contains(term))
            .toList();
    list.sort((a, b) {
      int r;
      if (_sort.by == 'date') {
        final da = DateTime.tryParse('${a[_dateKey] ?? ''}') ?? DateTime(0);
        final db = DateTime.tryParse('${b[_dateKey] ?? ''}') ?? DateTime(0);
        r = da.compareTo(db);
      } else {
        r = '${a[_sort.by] ?? ''}'.toLowerCase().compareTo('${b[_sort.by] ?? ''}'.toLowerCase());
      }
      return _sort.desc ? -r : r;
    });
    return list;
  }

  Future<void> _changeRole(Map<String, dynamic> u, String role) async {
    if (role == u['role']) return;
    try {
      await UserService.updateUser('${u['_id']}', {'role': role});
      if (!mounted) return;
      showSnack(context, '${u['name']} is now $role');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, apiErrorMessage(e, 'Failed to update role'));
    }
  }

  Future<void> _archive(Map<String, dynamic> u) {
    return showConfirmDialog(
      context,
      title: 'Archive user?',
      message:
          '"${u['name']}" will be deactivated and can no longer log in. Their transactions and history are kept, and you can restore them any time from the Archived tab.',
      confirmLabel: 'Archive',
      destructive: false,
      onConfirm: () async {
        try {
          await UserService.archiveUser('${u['_id']}');
          if (!mounted) return;
          showSnack(context, 'User archived. They can no longer log in; restore them from the Archived tab.');
          _load();
        } catch (e) {
          // e.g. "at least one active admin account must remain"
          if (mounted) showSnack(context, apiErrorMessage(e, 'Failed to archive user'));
        }
      },
    );
  }

  Future<void> _restore(Map<String, dynamic> u) async {
    try {
      await UserService.restoreUser('${u['_id']}');
      if (!mounted) return;
      showSnack(context, '${u['name']} restored. They can log in again.');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, apiErrorMessage(e, 'Failed to restore user'));
    }
  }

  Future<void> _deletePermanently(Map<String, dynamic> u) {
    return showPermanentDeleteDialog(
      context,
      title: 'Delete user permanently?',
      itemName: '${u['name']}',
      description:
          "Their profile picture is removed too. A user who has recorded transactions or purchase orders can't be deleted permanently and stays archived instead, so history remains accurate.",
      onConfirm: () async {
        try {
          final res = await UserService.permanentlyDeleteUser('${u['_id']}');
          if (!mounted) return;
          showSnack(context, '${res['message'] ?? 'User deleted'}');
          _load();
        } catch (e) {
          if (mounted) showSnack(context, apiErrorMessage(e, 'Failed to delete user permanently'));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final me = context.watch<AuthProvider>().user;
    final visible = _visible;
    final search = _searchCtl.text.trim();

    return PageContainer(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: ArchiveViewToggle(archived: _archived, onChanged: _setArchived),
                    ),
                  ),
                ),
                PopupMenuButton<_SortOption>(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort_rounded),
                  onSelected: (o) => setState(() => _sort = o),
                  itemBuilder: (_) => [
                    for (final o in _sortOptions)
                      CheckedPopupMenuItem(value: o, checked: o == _sort, child: Text(o.label)),
                  ],
                ),
                PrintTableButton<Map<String, dynamic>>(
                  title: _archived ? 'Archived Users' : 'Users',
                  subtitle: search.isEmpty ? '' : 'Search: "$search"',
                  columns: [
                    PrintColumn('Name', (u) => u['name']),
                    PrintColumn('Email', (u) => u['email']),
                    PrintColumn('Role', (u) => u['role'] == 'admin' ? 'Admin' : 'Staff'),
                    PrintColumn(_dateLabel, (u) => u[_dateKey] == null ? '' : formatDate(u[_dateKey])),
                  ],
                  getRows: (_, _) async => visible,
                  dateOf: (u) => u[_dateKey],
                  dateLabel: _archived ? 'archived' : 'joined',
                  disabled: _loading,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              _archived
                  ? 'Archived users are deactivated: they cannot log in, but their history is kept.'
                  : 'Archiving a user deactivates their account without erasing their history.',
              style: TextStyle(fontSize: 12.5, color: p.textSecondary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: ListSearchField(
              controller: _searchCtl,
              hint: 'Search by name or email…',
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildList(visible, me, search),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> visible, AppUser? me, String search) {
    if (_loading && _users.isEmpty) return const ListStatus.loading(padding: EdgeInsets.fromLTRB(16, 8, 16, 32));
    if (_error.isNotEmpty) return ListStatus.error(_error, onRetry: _load);
    if (visible.isEmpty) {
      return ListStatus.empty(
        emptyIcon: Icons.people_outline_rounded,
        emptyText: search.isNotEmpty
            ? 'No users match your search.'
            : _archived
                ? 'No archived users.'
                : 'No users yet.',
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final u = visible[i];
        final isSelf = '${u['_id']}' == me?.id;
        final role = '${u['role'] ?? 'staff'}';
        return ListRowCard(
          leading: UserAvatar(AppUser(u), radius: 20),
          title: '${u['name'] ?? ''}',
          titleTrailing: isSelf ? const SmallChip('You') : null,
          lines: [
            '${u['email'] ?? ''}',
            '$_dateLabel ${formatDate(u[_dateKey])}',
          ],
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_archived)
                SmallChip(role == 'admin' ? 'Admin' : 'Staff', outlined: true)
              else
                DropdownButton<String>(
                  value: role == 'admin' ? 'admin' : 'staff',
                  underline: const SizedBox.shrink(),
                  isDense: true,
                  borderRadius: BorderRadius.circular(12),
                  items: const [
                    DropdownMenuItem(value: 'staff', child: Text('Staff')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (v) {
                    if (v != null) _changeRole(u, v);
                  },
                ),
              PopupMenuButton<String>(
                tooltip: 'Actions',
                onSelected: (a) {
                  switch (a) {
                    case 'archive':
                      _archive(u);
                    case 'restore':
                      _restore(u);
                    case 'delete':
                      _deletePermanently(u);
                  }
                },
                itemBuilder: (_) => _archived
                    ? const [
                        PopupMenuItem(
                            value: 'restore',
                            child: ListTile(
                                leading: Icon(Icons.restore_from_trash_rounded), title: Text('Restore user'))),
                        PopupMenuItem(
                            value: 'delete',
                            child: ListTile(
                                leading: Icon(Icons.delete_forever_rounded, color: AppPalette.error),
                                title: Text('Delete permanently'))),
                      ]
                    : [
                        PopupMenuItem(
                          value: 'archive',
                          enabled: !isSelf,
                          child: ListTile(
                            leading: const Icon(Icons.archive_outlined, color: AppPalette.warningDark),
                            title: Text(isSelf ? "You can't archive your own account" : 'Archive user'),
                          ),
                        ),
                      ],
              ),
            ],
          ),
        );
      },
    );
  }
}
