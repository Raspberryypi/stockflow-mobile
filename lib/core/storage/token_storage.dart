import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage._();
  static const _storage = FlutterSecureStorage();

  static Future<String?> getToken() => _storage.read(key: 'token');

  static Future<void> save(String token, Map<String, dynamic> user) async {
    await _storage.write(key: 'token', value: token);
    await _storage.write(key: 'user', value: jsonEncode(user));
  }

  static Future<void> saveUser(Map<String, dynamic> user) =>
      _storage.write(key: 'user', value: jsonEncode(user));

  static Future<void> clear() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'user');
  }
}
