import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

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

Uint8List csvBytes(String csv) => Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);

String datedFileName(String base, String ext) {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '$base-${now.year}-${two(now.month)}-${two(now.day)}.$ext';
}
