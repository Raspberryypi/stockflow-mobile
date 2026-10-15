import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/format.dart';
import '../../widgets/transaction_type_chip.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction});
  final Map<String, dynamic> transaction;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final t = transaction;
    final product = asMap(t['product']);
    final type = '${t['type'] ?? ''}';
    final deleted = product['deletedAt'] != null;
    final location = describeLocation(t);
    final reasonOrSupplier = (type == 'STOCK_IN' ? t['supplier'] : t['reason'])?.toString() ?? '';
    final reference = t['referenceNumber']?.toString() ?? '';
    final by = asMap(t['performedBy'])['name']?.toString();

    final details = [
      if (location.isNotEmpty) location,
      if (reasonOrSupplier.isNotEmpty) reasonOrSupplier,
      if (reference.isNotEmpty) 'Ref $reference',
    ].join('  \u00B7  ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text('${product['name'] ?? '\u2014'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                      if (deleted) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: p.divider, borderRadius: BorderRadius.circular(6)),
                          child: Text('deleted',
                              style: TextStyle(fontSize: 11, color: p.textSecondary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('${product['sku'] ?? ''}',
                      style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(details, style: const TextStyle(fontSize: 13)),
                  ],
                  const SizedBox(height: 4),
                  Text('${by ?? '\u2014'}  \u00B7  ${formatDateTime(t['createdAt'])}',
                      style: TextStyle(fontSize: 12, color: p.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TransactionTypeChip(type),
                const SizedBox(height: 6),
                Text(formatInt(toNum(t['quantity'])),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
