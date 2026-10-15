import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/network/api_client.dart';
import '../core/utils/format.dart';
import '../core/utils/print_table.dart';
import '../providers/auth_provider.dart';
import 'app_alert.dart';

/// Port of components/common/PrintTableButton.jsx: one Print button for any
/// list. Prints a black-and-white report of the rows [getRows] returns.
///
///   getRows    fetch EVERYTHING matching the list's current filters (not
///              just what's loaded). Gets the chosen From/To dates.
///   dateOf     the date the From/To range filters on
///   dateLabel  names that date in the header ("created", "archived", ...)
///
/// Modes: default asks for a date range first; [fixedRange] prints straight
/// away with that range in the header; [snapshot] prints "As of now".
class PrintTableButton<T> extends StatefulWidget {
  const PrintTableButton({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.columns,
    required this.getRows,
    this.dateOf,
    this.dateLabel = '',
    this.initialFrom = '',
    this.initialTo = '',
    this.fixedRange,
    this.snapshot = false,
    this.landscape = false,
    this.disabled = false,
  });

  final String title;
  final String subtitle;
  final List<PrintColumn<T>> columns;
  final Future<List<T>> Function(String from, String to) getRows;
  final Object? Function(T row)? dateOf;
  final String dateLabel;
  final String initialFrom;
  final String initialTo;
  final (String, String)? fixedRange;
  final bool snapshot;
  final bool landscape;
  final bool disabled;

  @override
  State<PrintTableButton<T>> createState() => _PrintTableButtonState<T>();
}

class _PrintTableButtonState<T> extends State<PrintTableButton<T>> {
  bool _busy = false;

  Future<void> _onPressed() async {
    setState(() => _busy = true);
    await startPrintTable<T>(
      context,
      title: widget.title,
      subtitle: widget.subtitle,
      columns: widget.columns,
      getRows: widget.getRows,
      dateOf: widget.dateOf,
      dateLabel: widget.dateLabel,
      initialFrom: widget.initialFrom,
      initialTo: widget.initialTo,
      fixedRange: widget.fixedRange,
      snapshot: widget.snapshot,
      landscape: widget.landscape,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Print',
      onPressed: (widget.disabled || _busy) ? null : _onPressed,
      icon: _busy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.print_outlined),
    );
  }
}

/// The Print flow behind [PrintTableButton], for screens that start it from
/// a menu instead. Shows the date-range dialog unless [fixedRange] or
/// [snapshot] is set; errors without a dialog appear as a snackbar.
Future<void> startPrintTable<T>(
  BuildContext context, {
  required String title,
  String subtitle = '',
  required List<PrintColumn<T>> columns,
  required Future<List<T>> Function(String from, String to) getRows,
  Object? Function(T row)? dateOf,
  String dateLabel = '',
  String initialFrom = '',
  String initialTo = '',
  (String, String)? fixedRange,
  bool snapshot = false,
  bool landscape = false,
}) async {
  final needsDialog = !snapshot && fixedRange == null;
  final printedBy = context.read<AuthProvider>().user?.name ?? '';

  // Fetches, filters and prints. Returns an error message, or null on success.
  Future<String?> run(String from, String to) async {
    try {
      var rows = await getRows(from, to);
      if (needsDialog && dateOf != null) rows = filterByDateRange(rows, dateOf, from, to);
      if (rows.isEmpty) {
        return needsDialog ? 'No records found for that date range.' : 'There is nothing to print.';
      }
      await printTable<T>(
        title: title,
        subtitle: subtitle,
        columns: columns,
        rows: rows,
        from: from,
        to: to,
        dateLabel: dateLabel,
        snapshot: snapshot,
        printedBy: printedBy,
        landscape: landscape,
      );
      return null;
    } catch (e) {
      return apiErrorMessage(e, 'Could not prepare the print view.');
    }
  }

  if (needsDialog) {
    await showDialog<void>(
      context: context,
      builder: (_) => _PrintRangeDialog(
        title: title,
        initialFrom: initialFrom,
        initialTo: initialTo,
        onPrint: run,
      ),
    );
    return;
  }
  final error = await run(fixedRange?.$1 ?? '', fixedRange?.$2 ?? '');
  if (error != null && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }
}

class _PrintRangeDialog extends StatefulWidget {
  const _PrintRangeDialog({
    required this.title,
    required this.initialFrom,
    required this.initialTo,
    required this.onPrint,
  });
  final String title;
  final String initialFrom;
  final String initialTo;
  final Future<String?> Function(String from, String to) onPrint;

  @override
  State<_PrintRangeDialog> createState() => _PrintRangeDialogState();
}

class _PrintRangeDialogState extends State<_PrintRangeDialog> {
  late String _from = widget.initialFrom;
  late String _to = widget.initialTo;
  bool _busy = false;
  String _error = '';

  bool get _rangeInvalid {
    final a = parseDateInput(_from);
    final b = parseDateInput(_to);
    return a != null && b != null && a.isAfter(b);
  }

  void _preset(String preset) {
    final today = DateTime.now();
    setState(() {
      _error = '';
      switch (preset) {
        case 'today':
          _from = _to = formatDateInput(today);
        case 'week':
          _from = formatDateInput(today.subtract(const Duration(days: 6)));
          _to = formatDateInput(today);
        case 'month':
          _from = formatDateInput(DateTime(today.year, today.month, 1));
          _to = formatDateInput(today);
        default:
          _from = _to = '';
      }
    });
  }

  Future<void> _pick(bool isFrom) async {
    final current = parseDateInput(isFrom ? _from : _to) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _error = '';
      if (isFrom) {
        _from = formatDateInput(picked);
      } else {
        _to = formatDateInput(picked);
      }
    });
  }

  Future<void> _confirm() async {
    if (_rangeInvalid) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    final error = await widget.onPrint(_from, _to);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  Widget _dateField(String label, String value, bool isFrom) => Expanded(
        child: InkWell(
          onTap: _busy ? null : () => _pick(isFrom),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              suffixIcon: value.isEmpty
                  ? const Icon(Icons.calendar_today_rounded, size: 18)
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => isFrom ? _from = '' : _to = ''),
                    ),
            ),
            child: Text(value.isEmpty ? 'Any' : formatDate(value)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Print ${widget.title}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose a date range, or leave both empty to print everything.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(label: const Text('Today'), onPressed: () => _preset('today')),
                ActionChip(label: const Text('Last 7 days'), onPressed: () => _preset('week')),
                ActionChip(label: const Text('This month'), onPressed: () => _preset('month')),
                ActionChip(label: const Text('All dates'), onPressed: () => _preset('all')),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _dateField('From', _from, true),
                const SizedBox(width: 10),
                _dateField('To', _to, false),
              ],
            ),
            if (_rangeInvalid)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('"From" must be on or before "To".',
                    style: TextStyle(color: Colors.red, fontSize: 12.5)),
              ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 12),
              AppAlert(_error),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: (_busy || _rangeInvalid) ? null : _confirm,
          icon: const Icon(Icons.print_outlined, size: 18),
          label: Text(_busy ? 'Preparing…' : 'Print'),
        ),
      ],
    );
  }
}
