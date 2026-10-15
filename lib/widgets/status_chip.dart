import 'package:flutter/material.dart';
import '../core/theme/palette.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final (Color bg, Color fg) = switch (status) {
      'In Stock' => (AppPalette.success, Colors.white),
      'Low Stock' => (AppPalette.warning, Colors.white),
      'Out of Stock' => (AppPalette.error, Colors.white),
      _ => (p.dark ? const Color(0xFF3A4F52) : const Color(0xFFE0E0E0), p.textPrimary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
