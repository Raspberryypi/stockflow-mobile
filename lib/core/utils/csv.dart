import '../../widgets/transaction_type_chip.dart' show kTypeLabel;
import 'format.dart';

/// Port of utils/csvExport.js + utils/csvImport.js.
/// Writes and reads the same format, so an exported file re-imports cleanly.

String _escapeCell(Object? value) {
  final str = '${value ?? ''}';
  // Quote any cell containing a comma, quote, or newline, per CSV convention.
  return RegExp(r'[",\n]').hasMatch(str) ? '"${str.replaceAll('"', '""')}"' : str;
}

String _buildCsv(List<String> headers, List<List<Object?>> rows) => [
      headers.join(','),
      ...rows.map((r) => r.map(_escapeCell).join(',')),
    ].join('\n');

String productsToCsv(List<Map<String, dynamic>> products) => _buildCsv(
      ['Name', 'SKU', 'Category', 'Price', 'Quantity', 'Minimum Stock Level', 'Status', 'Supplier'],
      [
        for (final p in products)
          [
            p['name'],
            p['sku'],
            asMap(p['category'])['name'] ?? '',
            p['price'],
            p['quantity'],
            p['minimumStockLevel'],
            p['status'],
            p['supplier'] ?? '',
          ],
      ],
    );

String transactionsToCsv(List<Map<String, dynamic>> transactions) => _buildCsv(
      ['Date', 'Product', 'SKU', 'Type', 'Quantity', 'Location', 'Reason/Supplier', 'Reference', 'Performed By'],
      [
        for (final t in transactions)
          [
            formatDateTime(t['createdAt']),
            asMap(t['product'])['name'] ?? '',
            asMap(t['product'])['sku'] ?? '',
            kTypeLabel[t['type']] ?? t['type'],
            t['quantity'],
            describeLocation(t),
            t['type'] == 'STOCK_IN' ? t['supplier'] : t['reason'],
            t['referenceNumber'] ?? '',
            asMap(t['performedBy'])['name'] ?? '',
          ],
      ],
    );

/// Splits CSV text into rows of cells. Handles quoted cells containing
/// commas, newlines and escaped quotes.
List<List<String>> parseCsvRows(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;

  // Normalize line endings so \r\n from Excel doesn't leave stray \r.
  final input = text.replaceAll('\r\n', '\n').replaceFirst('﻿', '');

  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < input.length && input[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(char);
      }
    } else if (char == '"') {
      inQuotes = true;
    } else if (char == ',') {
      row.add(cell.toString());
      cell.clear();
    } else if (char == '\n') {
      row.add(cell.toString());
      rows.add(row);
      row = <String>[];
      cell.clear();
    } else {
      cell.write(char);
    }
  }
  // Final cell/row (files don't always end with a trailing newline).
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows.where((r) => r.length > 1 || r.first.isNotEmpty).toList();
}

// Export column headers (and a few common aliases) -> bulk-import field names.
const _headerAliases = {
  'name': 'name',
  'product name': 'name',
  'sku': 'sku',
  'category': 'category',
  'price': 'price',
  'quantity': 'quantity',
  'minimum stock level': 'minimumStockLevel',
  'min stock': 'minimumStockLevel',
  'status': 'status',
  'supplier': 'supplier',
  'description': 'description',
  'image url': 'imageUrl',
};

/// Parses a products CSV into row maps ready for
/// ProductService.bulkImportProducts. Throws [FormatException] with a
/// readable message when the file can't be used.
List<Map<String, dynamic>> parseProductsCsv(String text) {
  final rows = parseCsvRows(text);
  if (rows.isEmpty) throw const FormatException('The file appears to be empty.');

  final fields = rows.first.map((h) => _headerAliases[h.trim().toLowerCase()]).toList();
  if (!fields.contains('name') || !fields.contains('sku') || !fields.contains('category')) {
    throw const FormatException('CSV must include at least Name, SKU, and Category columns.');
  }

  return [
    for (final cells in rows.skip(1))
      {
        for (var i = 0; i < fields.length; i++)
          if (fields[i] != null) fields[i]!: (i < cells.length ? cells[i] : '').trim(),
      },
  ];
}
