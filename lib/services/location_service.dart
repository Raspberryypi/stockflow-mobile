import '../core/network/api_client.dart';

class LocationService {
  LocationService._();
  static final _api = ApiClient.instance;

  static Future<Map<String, dynamic>> getLocations([Map<String, dynamic>? params]) =>
      _api.get('/locations', params: params);
  static Future<Map<String, dynamic>> createLocation(Map<String, dynamic> payload) =>
      _api.post('/locations', payload);
  static Future<Map<String, dynamic>> updateLocation(String id, Map<String, dynamic> payload) =>
      _api.put('/locations/$id', payload);
  static Future<Map<String, dynamic>> deleteLocation(String id) => _api.delete('/locations/$id');
  static Future<Map<String, dynamic>> restoreLocation(String id) =>
      _api.post('/locations/$id/restore');
  static Future<Map<String, dynamic>> permanentlyDeleteLocation(String id) =>
      _api.delete('/locations/$id/permanent');
}
