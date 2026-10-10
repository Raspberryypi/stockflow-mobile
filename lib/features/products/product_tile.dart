import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';
import '../../core/utils/format.dart';
import '../../widgets/product_thumb.dart';
import '../../widgets/status_chip.dart';

enum ProductMenuAction { edit, archive, restore, deletePermanently }

/// One row of the products list (replaces a row of ProductTable.jsx).
/// - Normal view: tap = view, admin menu = Edit / Archive.
/// - Archived view: admin menu = Restore / Delete permanently.
/// - Selection mode (admin): a checkbox replaces the thumbnail.
class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.archived,
    required this.canManage,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
  });

  final Map<String, dynamic> product;
  final bool archived;
  final bool canManage;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final void Function(ProductMenuAction action) onMenu;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final category = asMap(product['category'])['name']?.toString();
    final imageUrl = product['imageUrl']?.toString();

    final subtitle = [
      '${product['sku'] ?? ''}',
      if (category != null && category.isNotEmpty) category,
    ].join('  ·  ');

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: selected ? p.primaryLight : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            children: [
              if (selectionMode)
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Checkbox(value: selected, onChanged: (_) => onTap()),
                )
              else
                ProductThumb(url: imageUrl, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${product['name'] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(formatCurrency(toNum(product['price'])),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                              archived
                                  ? 'Archived ${formatDate(product['deletedAt'])}'
                                  : 'Qty ${formatInt(toNum(product['quantity']))}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: p.textSecondary)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusChip('${product['status'] ?? ''}'),
              if (canManage && !selectionMode)
                PopupMenuButton<ProductMenuAction>(
                  tooltip: 'Actions',
                  icon: Icon(Icons.more_vert_rounded, color: p.textSecondary),
                  onSelected: onMenu,
                  itemBuilder: (_) => archived
                      ? const [
                          PopupMenuItem(
                            value: ProductMenuAction.restore,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.restore_from_trash_rounded),
                              title: Text('Restore'),
                            ),
                          ),
                          PopupMenuItem(
                            value: ProductMenuAction.deletePermanently,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.delete_forever_rounded, color: AppPalette.error),
                              title: Text('Delete permanently'),
                            ),
                          ),
                        ]
                      : const [
                          PopupMenuItem(
                            value: ProductMenuAction.edit,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.edit_rounded),
                              title: Text('Edit'),
                            ),
                          ),
                          PopupMenuItem(
                            value: ProductMenuAction.archive,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.archive_outlined, color: AppPalette.warning),
                              title: Text('Archive'),
                            ),
                          ),
                        ],
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
