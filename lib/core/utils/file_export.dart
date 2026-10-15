import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a generated file to the user (the web's "download" for mobile).
/// Opens the system "Save as" picker; where that isn't available, falls
/// back to the share sheet so the file can still be kept or sent.
/// Returns false only when the user cancelled.
Future<bool> saveOrShareFile({
  required String fileName,
  required Uint8List bytes,
  required String mimeType,
}) async {
  try {
    final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mimeType);
    return uri != null;
  } catch (_) {
    final result = await SharePlus.instance.share(ShareParams(
      files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
      fileNameOverrides: [fileName],
    ));
    return result.status != ShareResultStatus.dismissed;
  }
}

/// UTF-8 with a BOM so Excel shows ₱ and accented names correctly.
Uint8List csvBytes(String csv) => Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);

/// "inventory-export-2026-10-11.csv"
String datedFileName(String base, String ext) {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '$base-${now.year}-${two(now.month)}-${two(now.day)}.$ext';
}
