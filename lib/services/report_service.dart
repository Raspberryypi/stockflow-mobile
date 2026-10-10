import '../core/network/api_client.dart';

class ReportService {
  ReportService._();
  static final _api = ApiClient.instance;

  static Future<Map<String, dynamic>> getInventoryReport([Map<String, dynamic>? params]) =>
      _api.get('/reports/inventory', params: params);
}
