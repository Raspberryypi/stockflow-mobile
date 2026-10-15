import 'package:flutter/material.dart';
import '../core/theme/palette.dart';

const kTypeLabel = {
  'STOCK_IN': 'Stock In',
  'STOCK_OUT': 'Stock Out',
  'TRANSFER': 'Transfer',
};

class TransactionTypeChip extends StatelessWidget {
  const TransactionTypeChip(this.type, {super.key});
  final String type;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final (Color bg, Color fg) = switch (type) {
      'STOCK_IN' => (AppPalette.success, Colors.white),
      'TRANSFER' => (AppPalette.info, Colors.white),
      _ => (p.dark ? const Color(0xFF3A4F52) : const Color(0xFFE0E0E0), p.textPrimary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(kTypeLabel[type] ?? type,
          style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
