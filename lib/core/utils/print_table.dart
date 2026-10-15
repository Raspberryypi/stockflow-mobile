import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../config/app_config.dart';

/// One column of a printed table (same shape as the web's print columns).
class PrintColumn<T> {
  const PrintColumn(this.header, this.value, {this.alignRight = false});
  final String header;
  final Object? Function(T row) value;
  final bool alignRight;
}

const _systemName = 'Inventory Management System';

// ── Date helpers ('YYYY-MM-DD' strings, like the web's date inputs) ──

DateTime? parseDateInput(String? value) {
  if (value == null || value.isEmpty) return null;
  final parts = value.split('-').map(int.tryParse).toList();
  if (parts.length != 3 || parts.any((p) => p == null)) return null;
  return DateTime(parts[0]!, parts[1]!, parts[2]!);
}

String formatDateInput(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
String _longDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String _dateTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '${_longDate(d)}, $h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// Keeps rows whose date falls within [from, to] (whole days, inclusive).
/// Rows with no date are dropped when a range is set.
List<T> filterByDateRange<T>(List<T> rows, Object? Function(T) dateOf, String from, String to) {
  final start = parseDateInput(from);
  final end = parseDateInput(to);
  if (start == null && end == null) return rows;
  final endOfDay = end == null ? null : DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
  return rows.where((row) {
    final when = DateTime.tryParse('${dateOf(row) ?? ''}')?.toLocal();
    if (when == null) return false;
    if (start != null && when.isBefore(start)) return false;
    if (endOfDay != null && when.isAfter(endOfDay)) return false;
    return true;
  }).toList();
}

String _describeRange(String from, String to, bool snapshot, String dateLabel) {
  if (snapshot) return 'As of ${_dateTime(DateTime.now())}';
  final start = parseDateInput(from);
  final end = parseDateInput(to);
  String text;
  if (start != null && end != null) {
    text = 'From ${_longDate(start)} to ${_longDate(end)}';
  } else if (start != null) {
    text = 'From ${_longDate(start)} onward';
  } else if (end != null) {
    text = 'Up to ${_longDate(end)}';
  } else {
    text = 'All dates';
  }
  return dateLabel.isNotEmpty && (start != null || end != null) ? '$text (by date $dateLabel)' : text;
}

/// Port of utils/printTable.js: builds a black-and-white A4 report (title,
/// date range, who printed it, then the table, with the header repeated on
/// every page) and opens the system print dialog, which can also save a PDF.
Future<void> printTable<T>({
  required String title,
  String subtitle = '',
  required List<PrintColumn<T>> columns,
  required List<T> rows,
  String from = '',
  String to = '',
  String dateLabel = '',
  bool snapshot = false,
  String printedBy = '',
  bool landscape = false,
}) async {
  // Helvetica has no peso sign, so use Noto Sans when it can be fetched.
  pw.ThemeData theme;
  var hasPeso = true;
  try {
    theme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.notoSansRegular(),
      bold: await PdfGoogleFonts.notoSansBold(),
    );
  } catch (_) {
    theme = pw.ThemeData.base();
    hasPeso = false;
  }
  String clean(Object? v) {
    final text = (v == null || '$v'.isEmpty) ? '—' : '$v';
    return hasPeso ? text : text.replaceAll('₱', 'PHP ').replaceAll('—', '-');
  }

  final printedAt = _dateTime(DateTime.now());
  final rangeText = _describeRange(from, to, snapshot, dateLabel);
  const small = pw.TextStyle(fontSize: 9);
  final bold = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);

  final doc = pw.Document(title: '$title - ${formatDateInput(DateTime.now())}', theme: theme);
  doc.addPage(pw.MultiPage(
    pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(34), // ~12 mm
    header: (_) => pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 2))),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(clean('${AppConfig.brandName.toUpperCase()} · ${_systemName.toUpperCase()}'),
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
          pw.SizedBox(height: 3),
          pw.Text(clean(title), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          if (subtitle.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(clean(subtitle), style: small),
          ],
          pw.SizedBox(height: 5),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Date range: ', style: bold),
                  pw.TextSpan(text: clean(rangeText), style: small),
                ]),
              ),
              pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: 'Printed: ', style: bold),
                  pw.TextSpan(
                      text: clean(printedBy.isEmpty ? printedAt : '$printedAt by $printedBy'),
                      style: small),
                ]),
              ),
            ],
          ),
        ],
      ),
    ),
    footer: (ctx) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('Total records: ${rows.length}', style: const pw.TextStyle(fontSize: 8)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
      ],
    ),
    build: (_) => [
      pw.TableHelper.fromTextArray(
        headers: [for (final c in columns) clean(c.header)],
        data: [
          for (final row in rows) [for (final c in columns) clean(c.value(row))],
        ],
        border: pw.TableBorder.all(width: 0.6),
        headerStyle: bold,
        cellStyle: small,
        headerDecoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(width: 1.5))),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        headerAlignments: {
          for (var i = 0; i < columns.length; i++)
            i: columns[i].alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        },
        cellAlignments: {
          for (var i = 0; i < columns.length; i++)
            i: columns[i].alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        },
      ),
    ],
  ));

  await Printing.layoutPdf(
    name: '$title - ${formatDateInput(DateTime.now())}',
    onLayout: (_) => doc.save(),
  );
}
