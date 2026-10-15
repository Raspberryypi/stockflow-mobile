import '../core/network/api_client.dart';

class UserService {
  UserService._();
  static final _api = ApiClient.instance;

  static Future<Map<String, dynamic>> getUsers([Map<String, dynamic>? params]) =>
      _api.get('/users', params: params);
  static Future<Map<String, dynamic>> getUser(String id) => _api.get('/users/$id');
  static Future<Map<String, dynamic>> updateUser(String id, Map<String, dynamic> payload) =>
      _api.put('/users/$id', payload);
  static Future<Map<String, dynamic>> archiveUser(String id) => _api.delete('/users/$id');
  static Future<Map<String, dynamic>> restoreUser(String id) => _api.post('/users/$id/restore');
  static Future<Map<String, dynamic>> permanentlyDeleteUser(String id) =>
      _api.delete('/users/$id/permanent');
}
