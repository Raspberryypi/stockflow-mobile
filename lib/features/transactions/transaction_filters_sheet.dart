import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/transaction_type_chip.dart';

class TransactionFilterValues {
  const TransactionFilterValues({this.type = '', this.startDate = '', this.endDate = ''});
  final String type;
  final String startDate;
  final String endDate;

  int get activeCount =>
      (type.isNotEmpty ? 1 : 0) + (startDate.isNotEmpty ? 1 : 0) + (endDate.isNotEmpty ? 1 : 0);
}

Future<TransactionFilterValues?> showTransactionFiltersSheet(
  BuildContext context, {
  required TransactionFilterValues current,
}) {
  return showModalBottomSheet<TransactionFilterValues>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FiltersSheet(current: current),
  );
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.current});
  final TransactionFilterValues current;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late String _type = widget.current.type;
  late String _start = widget.current.startDate;
  late String _end = widget.current.endDate;

  static final _iso = DateFormat('yyyy-MM-dd');
  static final _pretty = DateFormat('MMM d, y');

  Future<void> _pickDate({required bool isStart}) async {
    final existing = DateTime.tryParse(isStart ? _start : _end);
    final picked = await showDatePicker(
      context: context,
      initialDate: existing ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = _iso.format(picked);
      } else {
        _end = _iso.format(picked);
      }
    });
  }

  Widget _dateField(String label, String value, {required bool isStart}) {
    final shown = DateTime.tryParse(value);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _pickDate(isStart: isStart),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value.isEmpty
              ? const Icon(Icons.calendar_today_rounded, size: 18)
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() => isStart ? _start = '' : _end = ''),
                ),
        ),
        child: Text(shown == null ? 'Any date' : _pretty.format(shown)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Filter transactions',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                const DropdownMenuItem(value: '', child: Text('All types')),
                for (final e in kTypeLabel.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _type = v ?? ''),
            ),
            const SizedBox(height: 14),
            _dateField('From', _start, isStart: true),
            const SizedBox(height: 14),
            _dateField('To', _end, isStart: false),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(const TransactionFilterValues()),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(
                      TransactionFilterValues(type: _type, startDate: _start, endDate: _end),
                    ),
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
