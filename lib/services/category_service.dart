import '../core/network/api_client.dart';

class CategoryService {
  CategoryService._();
  static final _api = ApiClient.instance;

  /// params: {'archived': true} lists archived categories (admin only).
  static Future<Map<String, dynamic>> getCategories([Map<String, dynamic>? params]) =>
      _api.get('/categories', params: params);
  static Future<Map<String, dynamic>> createCategory(Map<String, dynamic> payload) =>
      _api.post('/categories', payload);
  static Future<Map<String, dynamic>> updateCategory(String id, Map<String, dynamic> payload) =>
      _api.put('/categories/$id', payload);
  static Future<Map<String, dynamic>> deleteCategory(String id, {String? reassignTo}) =>
      _api.delete('/categories/$id',
          params: reassignTo != null ? {'reassignTo': reassignTo} : null);
  static Future<Map<String, dynamic>> restoreCategory(String id) =>
      _api.post('/categories/$id/restore');
  static Future<Map<String, dynamic>> permanentlyDeleteCategory(String id) =>
      _api.delete('/categories/$id/permanent');
}
