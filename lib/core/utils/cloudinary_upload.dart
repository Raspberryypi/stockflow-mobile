import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/product_service.dart';

/// Port of utils/productImageUpload.js + utils/cloudinaryUpload.js.
/// The signature comes from our server (it holds the API secret); the file
/// goes straight from the device/browser to Cloudinary.
const productImageMaxBytes = 5 * 1024 * 1024; // 5 MB
const _allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];
const _allowedMimeTypes = ['image/jpeg', 'image/png', 'image/webp'];

/// Returns an error message if the file can't be used, otherwise ''.
Future<String> validateProductImage(XFile file) async {
  final name = file.name.toLowerCase();
  final ext = name.contains('.') ? name.split('.').last : '';
  final mime = (file.mimeType ?? '').toLowerCase();
  if (!_allowedExtensions.contains(ext) && !_allowedMimeTypes.contains(mime)) {
    return 'Please choose a JPG, PNG or WebP image.';
  }
  if (await file.length() > productImageMaxBytes) {
    return 'Image is too large. Maximum size is 5 MB.';
  }
  return '';
}

/// Uploads a product image to Cloudinary and resolves with its https URL.
Future<String> uploadProductImage(XFile file) async {
  final sigRes = await ProductService.getProductImageSignature();
  return uploadToCloudinary(Map<String, dynamic>.from(sigRes['data'] as Map), file);
}

/// Port of utils/avatarUpload.js.
const avatarMaxBytes = 2 * 1024 * 1024; // 2 MB

/// Returns an error message if the file can't be used, otherwise ''.
Future<String> validateAvatarImage(XFile file) async {
  final name = file.name.toLowerCase();
  final ext = name.contains('.') ? name.split('.').last : '';
  final mime = (file.mimeType ?? '').toLowerCase();
  if (!_allowedExtensions.contains(ext) && !_allowedMimeTypes.contains(mime)) {
    return 'Please choose a JPG, PNG or WebP image.';
  }
  if (await file.length() > avatarMaxBytes) {
    return 'Image is too large. Maximum size is 2 MB.';
  }
  return '';
}

/// Uploads the picture to Cloudinary (signed by our server), saves the URL
/// on the account, and resolves with the updated user data.
Future<Map<String, dynamic>> uploadAvatar(XFile file) async {
  final sigRes = await AuthService.getAvatarUploadSignature();
  final url = await uploadToCloudinary(Map<String, dynamic>.from(sigRes['data'] as Map), file);
  final saved = await AuthService.updateAvatar(url);
  return Map<String, dynamic>.from(saved['data'] as Map);
}

/// Sends [file] straight to Cloudinary with a signature from our server
/// (which holds the API secret). Resolves with the https URL.
/// Uses a plain Dio on purpose: the app's shared client would attach the
/// login token and API base URL to a request that goes to Cloudinary.
Future<String> uploadToCloudinary(Map<String, dynamic> sig, XFile file) async {
  final params = Map<String, dynamic>.from((sig['params'] as Map?) ?? const {});
  final bytes = await file.readAsBytes();
  final form = FormData();
  form.files.add(MapEntry('file', MultipartFile.fromBytes(bytes, filename: file.name)));
  form.fields.add(MapEntry('api_key', '${sig['apiKey']}'));
  form.fields.add(MapEntry('signature', '${sig['signature']}'));
  params.forEach((key, value) => form.fields.add(MapEntry(key, '$value')));

  try {
    final res = await Dio().post(
      'https://api.cloudinary.com/v1_1/${sig['cloudName']}/image/upload',
      data: form,
    );
    final data = res.data;
    final url = data is Map ? data['secure_url'] : null;
    if (url is String && url.isNotEmpty) return url;
    throw Exception('Upload failed. Please try again.');
  } on DioException catch (e) {
    final data = e.response?.data;
    final err = data is Map ? data['error'] : null;
    final msg = err is Map ? err['message'] : null;
    throw Exception(msg is String ? msg : 'Upload failed. Please try again.');
  }
}
