import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final Dio _dio = Dio();
  String? _baseUrl;
  String? _token;

  ApiService() {
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('api_base_url');
    _token = prefs.getString('auth_token');
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', _baseUrl!);
  }

  Future<bool> login(String email, String password) async {
    if (_baseUrl == null) throw Exception("API URL not set");

    try {
      final response = await _dio.post(
        '$_baseUrl/api/v1/passport/auth/login',
        data: {'email': email, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      if (response.data['data'] != null &&
          response.data['data']['auth_data'] != null) {
        _token = response.data['data']['auth_data'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', _token!);
        return true;
      }
      return false;
    } catch (e) {
      if (e is DioException) {
        if (e.response != null) {
          throw Exception(
            "Login failed: ${e.response?.data['message'] ?? e.message}",
          );
        }
      }
      throw Exception("Network error: $e");
    }
  }

  Future<void> logout() async {
    _token = null;
    _baseUrl = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs
        .clear(); // Wipe everything including theme/lang prefs? Or filter?
    // User requested "exit account means wiping everything like a new environment".
    // So prefs.clear() is appropriate per user request "everything... including subscription cache etc".
  }

  Future<List<dynamic>> fetchSubscribe() async {
    if (_baseUrl == null || _token == null) {
      // Try reload just in case
      await _loadConfig();
      if (_baseUrl == null || _token == null) throw Exception("Not authorized");
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/api/v1/user/getSubscribe',
        options: Options(headers: {'Authorization': _token}),
      );

      if (response.data['data'] != null) {
        return response.data['data'];
      }
      return [];
    } catch (e) {
      throw e;
    }
  }

  bool get isAuthenticated => _token != null;
}
