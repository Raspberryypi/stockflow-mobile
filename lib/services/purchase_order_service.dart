import '../core/network/api_client.dart';

class PurchaseOrderService {
  PurchaseOrderService._();
  static final _api = ApiClient.instance;

  static Future<Map<String, dynamic>> getPurchaseOrders([Map<String, dynamic>? params]) =>
      _api.get('/purchase-orders', params: params);
  static Future<Map<String, dynamic>> getReorderSuggestions() =>
      _api.get('/purchase-orders/reorder-suggestions');
  static Future<Map<String, dynamic>> createPurchaseOrder(Map<String, dynamic> payload) =>
      _api.post('/purchase-orders', payload);
  static Future<Map<String, dynamic>> updatePurchaseOrder(String id, Map<String, dynamic> payload) =>
      _api.put('/purchase-orders/$id', payload);
  static Future<Map<String, dynamic>> markOrdered(String id) =>
      _api.post('/purchase-orders/$id/order');
  static Future<Map<String, dynamic>> cancelPurchaseOrder(String id) =>
      _api.post('/purchase-orders/$id/cancel');
  static Future<Map<String, dynamic>> receivePurchaseOrder(String id,
          [Map<String, dynamic> payload = const {}]) =>
      _api.post('/purchase-orders/$id/receive', payload);
  static Future<Map<String, dynamic>> deletePurchaseOrder(String id) =>
      _api.delete('/purchase-orders/$id');
}
