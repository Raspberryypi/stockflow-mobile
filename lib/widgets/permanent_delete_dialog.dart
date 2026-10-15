import 'package:flutter/material.dart';
import '../core/theme/palette.dart';
import 'app_alert.dart';

const _confirmWord = 'DELETE';

Future<void> showPermanentDeleteDialog(
  BuildContext context, {
  String title = 'Delete permanently?',
  required String itemName,
  String? description,
  required Future<void> Function() onConfirm,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PermanentDeleteDialog(
      title: title,
      itemName: itemName,
      description: description,
      onConfirm: onConfirm,
    ),
  );
}

class _PermanentDeleteDialog extends StatefulWidget {
  const _PermanentDeleteDialog({
    required this.title,
    required this.itemName,
    required this.description,
    required this.onConfirm,
  });

  final String title;
  final String itemName;
  final String? description;
  final Future<void> Function() onConfirm;

  @override
  State<_PermanentDeleteDialog> createState() => _PermanentDeleteDialogState();
}

class _PermanentDeleteDialogState extends State<_PermanentDeleteDialog> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canConfirm => _controller.text.trim() == _confirmWord && !_loading;

  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      await widget.onConfirm();
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppAlert('${widget.itemName} will be erased for good. This cannot be undone.'),
            if (widget.description != null) ...[
              Text(widget.description!, style: TextStyle(color: p.textSecondary)),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              enabled: !_loading,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Type $_confirmWord to confirm',
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppPalette.error),
          onPressed: _canConfirm ? _confirm : null,
          child: Text(_loading ? 'Deleting…' : 'Delete permanently'),
        ),
      ],
    );
  }
}
