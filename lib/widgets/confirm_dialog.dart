import 'package:flutter/material.dart';
import '../core/theme/palette.dart';

/// Port of components/common/ConfirmDialog.jsx.
/// Shows a dialog; while [onConfirm] runs the buttons are disabled and the
/// label reads "Please wait…". Closes itself when [onConfirm] finishes.
Future<void> showConfirmDialog(
  BuildContext context, {
  String title = 'Are you sure?',
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = true,
  required Future<void> Function() onConfirm,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
      onConfirm: onConfirm,
    ),
  );
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
  final Future<void> Function() onConfirm;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _loading = false;

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
      content: Text(widget.message, style: TextStyle(color: p.textSecondary)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: widget.destructive ? AppPalette.error : AppPalette.primary,
          ),
          onPressed: _loading ? null : _confirm,
          child: Text(_loading ? 'Please wait…' : widget.confirmLabel),
        ),
      ],
    );
  }
}
