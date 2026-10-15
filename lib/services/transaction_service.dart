import '../core/network/api_client.dart';

class TransactionService {
  TransactionService._();
  static final _api = ApiClient.instance;

  static Future<Map<String, dynamic>> getTransactions([Map<String, dynamic>? params]) =>
      _api.get('/transactions', params: params);
  static Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> payload) =>
      _api.post('/transactions', payload);

  static Future<Map<String, dynamic>> transferStock(Map<String, dynamic> payload) =>
      _api.post('/transactions/transfer', payload);
}
