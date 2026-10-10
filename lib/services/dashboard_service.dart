import '../core/network/api_client.dart';

class DashboardService {
  DashboardService._();
  static final _api = ApiClient.instance;

  static Future<Map<String, dynamic>> getStats() => _api.get('/dashboard/stats');
  static Future<Map<String, dynamic>> sendLowStockAlertNow() =>
      _api.post('/dashboard/low-stock-alert/send');
}
