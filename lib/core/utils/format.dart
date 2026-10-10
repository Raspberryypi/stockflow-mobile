import 'package:intl/intl.dart';

final NumberFormat _moneyFmt = NumberFormat('#,##0.00', 'en_US');
final NumberFormat _intFmt = NumberFormat('#,##0', 'en_US');
final DateFormat _dateFmt = DateFormat('MMM d, y');
final DateFormat _dateTimeFmt = DateFormat('MMM d, y \u00B7 h:mm a');

/// Port of utils/currency.js (Philippine peso).
String formatCurrency(num? value) => '\u20B1${_moneyFmt.format(value ?? 0)}';

String formatInt(num? value) => _intFmt.format(value ?? 0);

/// ISO string -> "Oct 11, 2026" (local time). "—" when missing/invalid.
String formatDate(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}');
  return d == null ? '\u2014' : _dateFmt.format(d.toLocal());
}

/// ISO string -> "Oct 11, 2026 · 3:45 PM" (local time). "—" when missing/invalid.
String formatDateTime(Object? iso) {
  final d = DateTime.tryParse('${iso ?? ''}');
  return d == null ? '\u2014' : _dateTimeFmt.format(d.toLocal());
}

/// "Warehouse A", "Main → Store 2", or '' when a movement wasn't tied to a
/// location (port of describeLocation in utils/transactionLabels.js).
String describeLocation(Map<String, dynamic> t) {
  if (t['type'] == 'TRANSFER') {
    final from = asMap(t['fromLocation'])['name']?.toString() ?? 'Unassigned';
    final to = asMap(t['toLocation'])['name']?.toString() ?? 'Unassigned';
    return '$from \u2192 $to';
  }
  return asMap(t['location'])['name']?.toString() ?? '';
}

num toNum(Object? v) => v is num ? v : (num.tryParse('$v') ?? 0);

/// JSON helpers: the API client returns loosely-typed maps.
Map<String, dynamic> asMap(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<Map<String, dynamic>> asMapList(Object? v) =>
    v is List ? v.map(asMap).toList() : <Map<String, dynamic>>[];
