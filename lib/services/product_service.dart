import '../core/network/api_client.dart';

class ProductService {
  ProductService._();
  static final _api = ApiClient.instance;

  static Future<Map<String, dynamic>> getProducts([Map<String, dynamic>? params]) =>
      _api.get('/products', params: params);
  static Future<Map<String, dynamic>> getProduct(String id) => _api.get('/products/$id');
  static Future<Map<String, dynamic>> createProduct(Map<String, dynamic> payload) =>
      _api.post('/products', payload);
  static Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> payload) =>
      _api.put('/products/$id', payload);

  /// Archives the product (soft delete). Reversible via [restoreProduct].
  static Future<Map<String, dynamic>> deleteProduct(String id) => _api.delete('/products/$id');
  static Future<Map<String, dynamic>> restoreProduct(String id) => _api.post('/products/$id/restore');

  /// Irreversible. Only works on an already-archived product.
  static Future<Map<String, dynamic>> permanentlyDeleteProduct(String id) =>
      _api.delete('/products/$id/permanent');

  static Future<Map<String, dynamic>> bulkArchiveProducts(List<String> ids) =>
      _api.post('/products/bulk-archive', {'ids': ids});
  static Future<Map<String, dynamic>> bulkReassignCategory(List<String> ids, String category) =>
      _api.post('/products/bulk-reassign-category', {'ids': ids, 'category': category});
  static Future<Map<String, dynamic>> bulkImportProducts(List<Map<String, dynamic>> products) =>
      _api.post('/products/bulk-import', {'products': products});

  static Future<Map<String, dynamic>> getProductBySku(String sku) =>
      _api.get('/products/sku/${Uri.encodeComponent(sku)}');
  static Future<Map<String, dynamic>> getProductStock(String id) => _api.get('/products/$id/stock');
  static Future<Map<String, dynamic>> getProductImageSignature() =>
      _api.post('/products/image/signature');
}
