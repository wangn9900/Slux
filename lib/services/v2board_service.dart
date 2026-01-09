import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/remote_config.dart';
import '../providers/resource_provider.dart';

class V2BoardLoginResponse {
  final String token;
  final int expireAt;
  final int planId;
  final String email;

  V2BoardLoginResponse({
    required this.token,
    required this.expireAt,
    required this.planId,
    required this.email,
  });

  factory V2BoardLoginResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return V2BoardLoginResponse(
      token: data['auth_data'] ?? data['token'] ?? '',
      expireAt: data['expire_at'] ?? 0,
      planId: data['plan_id'] ?? 0,
      email: data['email'] ?? '',
    );
  }
}

class V2BoardService {
  final Ref ref;
  final Dio _dio = Dio();
  String? _cachedApiBase; // 缓存已验证可用的 API 地址

  V2BoardService(this.ref) {
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers = {'Accept': 'application/json, text/plain, */*'};
  }

  /// 从 OSS 获取并选择可用的 API 地址
  Future<String?> _getWorkingApiBase() async {
    if (_cachedApiBase != null) return _cachedApiBase;

    final prefs = await SharedPreferences.getInstance();
    final lastWorking = prefs.getString('last_working_api');
    if (lastWorking != null) {
      if (await _testApiEndpoint(lastWorking)) {
        _cachedApiBase = lastWorking;
        return lastWorking;
      }
    }

    final resourceService = ref.read(remoteResourceProvider);
    final configMap = await resourceService.fetchRemoteConfig();
    if (configMap == null) return null;

    final config = RemoteConfig.fromJson(configMap);
    final allEndpoints = config.getAllEndpoints();

    if (allEndpoints.isEmpty) return null;

    for (final endpoint in allEndpoints) {
      if (kDebugMode) print('Testing API endpoint: $endpoint');
      if (await _testApiEndpoint(endpoint)) {
        _cachedApiBase = endpoint;
        await prefs.setString('last_working_api', endpoint);
        if (kDebugMode) print('Found working API: $endpoint');
        return endpoint;
      }
    }
    return null;
  }

  Future<bool> _testApiEndpoint(String baseUrl) async {
    try {
      final testUrl = '$baseUrl/api/v1/guest/comm/config';
      final resp = await _dio.get(
        testUrl,
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return resp.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<V2BoardLoginResponse?> login({
    required String email,
    required String password,
  }) async {
    // ... existing login implementation ...
    final apiBase = await _getWorkingApiBase();
    if (apiBase == null) return null;
    final loginUrl = '$apiBase/api/v1/passport/auth/login';
    try {
      final resp = await _dio.post(
        loginUrl,
        data: {'email': email, 'password': password},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (resp.statusCode == 200 && resp.data != null) {
        final loginResp = V2BoardLoginResponse.fromJson(resp.data);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('v2board_token', loginResp.token);
        await prefs.setString('v2board_email', loginResp.email);
        await prefs.setString('v2board_api_base', apiBase);
        return loginResp;
      }
    } catch (e) {
      if (kDebugMode) print('V2Board login error: $e');
      if (e is DioException)
        throw Exception(
            e.response?.data['message'] ?? e.message); // Rethrow properly
    }
    return null;
  }

  // --- Auth Methods (Register & Reset) ---

  Future<bool> sendEmailVerify(String email) async {
    final apiBase = await _getWorkingApiBase();
    if (apiBase == null) return false;
    final url = '$apiBase/api/v1/passport/comm/sendEmailVerify';
    try {
      final resp = await _dio.post(
        url,
        data: FormData.fromMap({'email': email}),
      );
      return resp.statusCode == 200 && resp.data['data'] == true;
    } catch (e) {
      if (kDebugMode) print('Error sending email verify: $e');
      if (e is DioException)
        throw Exception(e.response?.data['message'] ?? e.message);
    }
    return false;
  }

  Future<V2BoardLoginResponse?> register({
    required String email,
    required String password,
    required String verifyCode,
    String? inviteCode,
  }) async {
    final apiBase = await _getWorkingApiBase();
    if (apiBase == null) return null;
    final url = '$apiBase/api/v1/passport/auth/register';
    try {
      final data = {
        'email': email,
        'password': password,
        'email_code': verifyCode,
        if (inviteCode != null && inviteCode.isNotEmpty)
          'invite_code': inviteCode,
      };
      final resp = await _dio.post(url, data: FormData.fromMap(data));

      if (resp.statusCode == 200 && resp.data['data'] != null) {
        // Register usually returns token similar to login, or just success.
        // MOMclash handles this by checking auth_data.
        // Let's assume it returns login data or we need to login manually.
        // According to MOMclash code: it returns auth_data (token).
        final loginResp = V2BoardLoginResponse.fromJson(resp.data);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('v2board_token', loginResp.token);
        await prefs.setString('v2board_email', loginResp.email);
        await prefs.setString('v2board_api_base', apiBase);
        return loginResp;
      }
    } catch (e) {
      if (kDebugMode) print('Error registering: $e');
      if (e is DioException)
        throw Exception(e.response?.data['message'] ?? e.message);
    }
    return null;
  }

  Future<bool> forgetPassword({
    required String email,
    required String password,
    required String verifyCode,
  }) async {
    final apiBase = await _getWorkingApiBase();
    if (apiBase == null) return false;
    final url = '$apiBase/api/v1/passport/auth/forget';
    try {
      final resp = await _dio.post(
        url,
        data: FormData.fromMap({
          'email': email,
          'password': password,
          'email_code': verifyCode,
        }),
      );
      return resp.statusCode == 200 && resp.data['data'] == true;
    } catch (e) {
      if (kDebugMode) print('Error forgetting password: $e');
      if (e is DioException)
        throw Exception(e.response?.data['message'] ?? e.message);
    }
    return false;
  }

  Future<String?> getSubscribeUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return null;

    try {
      final url = '$apiBase/api/v1/user/getSubscribe';
      final resp = await _dio.get(
        url,
        options: Options(headers: {'Authorization': token}),
      );
      if (resp.statusCode == 200 && resp.data != null) {
        final data = resp.data['data'];
        return data['subscribe_url'].toString();
      }
    } catch (e) {
      if (kDebugMode) print('Get subscribe URL error: $e');
    }
    return null;
  }

  Future<String?> fetchSubscriptionContent() async {
    final subUrl = await getSubscribeUrl();
    if (subUrl == null) return null;
    try {
      final resp = await _dio.get(subUrl);
      if (resp.statusCode == 200) {
        return resp.data.toString();
      }
    } catch (e) {
      if (kDebugMode) print('Fetch subscription error: $e');
    }
    return null;
  }

  Future<List<dynamic>?> getPlans() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return null;
    final url = '$apiBase/api/v1/user/plan/fetch';

    try {
      final resp = await _dio.get(
        url,
        options: Options(headers: {'Authorization': token}),
      );
      if (resp.statusCode == 200) {
        return resp.data['data'] as List<dynamic>?;
      }
    } catch (e) {
      if (kDebugMode) print('V2Board getPlans error: $e');
    }
    return null;
  }

  /// 获取用户信息
  Future<Map<String, dynamic>?> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return null;
    final url = '$apiBase/api/v1/user/info';

    try {
      final resp = await _dio.get(
        url,
        options: Options(headers: {'Authorization': token}),
      );
      if (resp.statusCode == 200 && resp.data['data'] != null) {
        return resp.data['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      if (kDebugMode) print('V2Board getUserInfo error: $e');
    }
    return null;
  }

  /// 获取站点公开配置
  Future<Map<String, dynamic>?> getCommConfig() async {
    final apiBase = await _getWorkingApiBase();
    if (apiBase == null) return null;
    final url = '$apiBase/api/v1/guest/comm/config';
    try {
      final resp = await _dio.get(url);
      if (resp.statusCode == 200 && resp.data['data'] != null) {
        return resp.data['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      // 忽略错误
    }
    return null;
  }

  // --- New Methods for Shop & Payment (Ported from MOMclash) ---

  /// 提交订单
  Future<String?> submitOrder({
    required int planId,
    required String period,
    String? couponCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();
    if (token == null || apiBase == null) return null;

    final url = '$apiBase/api/v1/user/order/save';

    try {
      final data = {
        'plan_id': planId,
        'period': period,
        if (couponCode != null && couponCode.isNotEmpty)
          'coupon_code': couponCode,
      };

      final resp = await _dio.post(
        url,
        data: FormData.fromMap(data),
        options: Options(headers: {'Authorization': token}),
      );

      if (resp.statusCode == 200 && resp.data['data'] != null) {
        final responseData = resp.data['data'];
        if (responseData is String) return responseData;
        if (responseData is Map && responseData['trade_no'] != null) {
          return responseData['trade_no'].toString();
        }
      }
    } catch (e) {
      if (kDebugMode) print('submitOrder error: $e');
      if (e is DioException) {
        final msg = e.response?.data['message'];
        if (msg != null) throw msg;
      }
    }
    return null;
  }

  /// 获取支付方式
  Future<List<dynamic>?> getPaymentMethods() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();
    if (token == null || apiBase == null) return null;

    final url = '$apiBase/api/v1/user/order/getPaymentMethod';
    try {
      final resp = await _dio.get(
        url,
        options: Options(headers: {'Authorization': token}),
      );
      if (resp.statusCode == 200 && resp.data['data'] != null) {
        return resp.data['data'];
      }
    } catch (e) {
      if (kDebugMode) print('getPaymentMethods error: $e');
    }
    return null;
  }

  /// 结账（获取支付参数/跳转链接）
  Future<dynamic> checkoutOrder({
    required String tradeNo,
    required int methodId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();
    if (token == null || apiBase == null) return null;

    final url = '$apiBase/api/v1/user/order/checkout';

    // Construct Referer (important for some payment gateways)
    final uri = Uri.parse(apiBase);
    final refererUrl =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/';

    try {
      final resp = await _dio.post(
        url,
        data: FormData.fromMap({
          'trade_no': tradeNo,
          'method': methodId,
          'return_url': '$apiBase/payment/return', // Placeholder
        }),
        options: Options(
          headers: {'Authorization': token, 'Referer': refererUrl},
        ),
      );

      if (resp.statusCode == 200) {
        return resp.data; // Return full data (type, data)
      }
    } catch (e) {
      if (kDebugMode) print('checkoutOrder error: $e');
      if (e is DioException) {
        final msg = e.response?.data['message'];
        if (msg != null) throw msg;
      }
    }
    return null;
  }

  /// 获取历史订单
  Future<List<dynamic>?> fetchOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();
    if (token == null || apiBase == null) return null;

    final url = '$apiBase/api/v1/user/order/fetch';
    try {
      final resp = await _dio.get(
        url,
        options: Options(headers: {'Authorization': token}),
      );
      if (resp.statusCode == 200 && resp.data['data'] != null) {
        return resp.data['data'];
      }
    } catch (e) {
      if (kDebugMode) print('fetchOrders error: $e');
    }
    return null;
  }

  /// 取消订单
  Future<bool> cancelOrder(String tradeNo) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();
    if (token == null || apiBase == null) return false;

    final url = '$apiBase/api/v1/user/order/cancel';
    try {
      final resp = await _dio.post(
        url,
        data: FormData.fromMap({'trade_no': tradeNo}),
        options: Options(headers: {'Authorization': token}),
      );
      return resp.statusCode == 200 && resp.data['data'] == true;
    } catch (e) {
      if (kDebugMode) print('cancelOrder error: $e');
    }
    return false;
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('v2board_token') != null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('v2board_token');
    await prefs.remove('v2board_email');
    await prefs.remove('v2board_api_base');
    _cachedApiBase = null;
  }

  Future<String?> refreshApiEndpoint() async {
    _cachedApiBase = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_working_api');
    return await _getWorkingApiBase();
  }
  // --- New Methods for User Center & Traffic Details ---

  /// 获取流量日志
  Future<dynamic> getTrafficLog() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return null;
    final url = '$apiBase/api/v1/user/stat/getTrafficLog';

    try {
      final resp = await _dio.get(
        url,
        options: Options(headers: {'Authorization': token}),
      );
      if (resp.statusCode == 200 && resp.data['data'] != null) {
        return resp.data['data'];
      }
    } catch (e) {
      if (kDebugMode) print('getTrafficLog error: $e');
    }
    return null;
  }

  /// 兑换礼品卡
  Future<Map<String, dynamic>> redeemGiftCard(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null)
      return {'success': false, 'message': '未登录'};
    final url = '$apiBase/api/v1/user/redeemgiftcard';

    try {
      final resp = await _dio.post(
        url,
        data: FormData.fromMap({'giftcard': code}),
        options: Options(headers: {'Authorization': token}),
      );
      if (resp.statusCode == 200) {
        return {
          'success': resp.data['data'] == true,
          'message': resp.data['message'] ?? '兑换成功',
        };
      }
      return {'success': false, 'message': resp.data['message'] ?? '兑换失败'};
    } catch (e) {
      if (kDebugMode) print('redeemGiftCard error: $e');
      if (e is DioException && e.response?.data != null) {
        return {
          'success': false,
          'message': e.response?.data['message'] ?? '兑换失败',
        };
      }
      return {'success': false, 'message': '网络错误'};
    }
  }

  /// 修改密码
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return false;
    final url = '$apiBase/api/v1/user/changePassword';

    try {
      final resp = await _dio.post(
        url,
        data: FormData.fromMap({
          'old_password': oldPassword,
          'new_password': newPassword,
        }),
        options: Options(headers: {'Authorization': token}),
      );
      return resp.statusCode == 200 && resp.data['data'] == true;
    } catch (e) {
      if (kDebugMode) print('changePassword error: $e');
    }
    return false;
  }

  /// 更新用户信息（如通知设置）
  Future<bool> updateUserInfo(Map<String, dynamic> params) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return false;
    final url = '$apiBase/api/v1/user/update';

    try {
      final resp = await _dio.post(
        url,
        data: FormData.fromMap(params),
        options: Options(headers: {'Authorization': token}),
      );
      return resp.statusCode == 200 && resp.data['data'] == true;
    } catch (e) {
      if (kDebugMode) print('updateUserInfo error: $e');
    }
    return false;
  }

  // --- Ticket Methods ---

  Future<List<dynamic>?> fetchTickets() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return null;
    final url = '$apiBase/api/v1/user/ticket/fetch';

    try {
      final resp = await _dio.get(
        url,
        options: Options(headers: {'Authorization': token}),
      );
      if (resp.statusCode == 200 && resp.data['data'] != null) {
        return resp.data['data'];
      }
    } catch (e) {
      if (kDebugMode) print('fetchTickets error: $e');
    }
    return null;
  }

  Future<dynamic> getTicketDetail(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return null;
    final url = '$apiBase/api/v1/user/ticket/fetch?id=$id';

    try {
      final resp = await _dio.get(
        url,
        options: Options(headers: {'Authorization': token}),
      );
      if (resp.statusCode == 200 && resp.data['data'] != null) {
        return resp.data['data'];
      }
    } catch (e) {
      if (kDebugMode) print('getTicketDetail error: $e');
    }
    return null;
  }

  Future<bool> createTicket(
    String subject,
    String level,
    String message,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return false;
    final url = '$apiBase/api/v1/user/ticket/save';

    try {
      final resp = await _dio.post(
        url,
        data: FormData.fromMap({
          'subject': subject,
          'level': level,
          'message': message,
        }),
        options: Options(headers: {'Authorization': token}),
      );
      return resp.statusCode == 200 && resp.data['data'] == true;
    } catch (e) {
      if (kDebugMode) print('createTicket error: $e');
    }
    return false;
  }

  Future<bool> replyTicket(int id, String message) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return false;
    final url = '$apiBase/api/v1/user/ticket/reply';

    try {
      final resp = await _dio.post(
        url,
        data: FormData.fromMap({'id': id, 'message': message}),
        options: Options(headers: {'Authorization': token}),
      );
      return resp.statusCode == 200 && resp.data['data'] == true;
    } catch (e) {
      if (kDebugMode) print('replyTicket error: $e');
    }
    return false;
  }

  Future<bool> closeTicket(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return false;
    final url = '$apiBase/api/v1/user/ticket/close';

    try {
      final resp = await _dio.post(
        url,
        data: FormData.fromMap({'id': id}),
        options: Options(headers: {'Authorization': token}),
      );
      return resp.statusCode == 200 && resp.data['data'] == true;
    } catch (e) {
      if (kDebugMode) print('closeTicket error: $e');
    }
    return false;
  }

  // --- Invite Methods ---

  Future<Map<String, dynamic>?> getInviteData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return null;
    final url = '$apiBase/api/v1/user/invite/fetch';

    try {
      final resp = await _dio.get(
        url,
        options: Options(headers: {'Authorization': token}),
      );
      if (resp.statusCode == 200 && resp.data['data'] != null) {
        return Map<String, dynamic>.from(resp.data['data']);
      }
    } catch (e) {
      if (kDebugMode) print('getInviteData error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> getInviteDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return null;
    final url = '$apiBase/api/v1/user/invite/details';

    try {
      final resp = await _dio.get(
        url,
        options: Options(headers: {'Authorization': token}),
      );
      if (resp.statusCode == 200 && resp.data['data'] != null) {
        return Map<String, dynamic>.from(resp.data['data']);
      }
    } catch (e) {
      if (kDebugMode) print('getInviteDetails error: $e');
    }
    return null;
  }

  Future<bool> generateInviteCode() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return false;
    final url = '$apiBase/api/v1/user/invite/save';

    try {
      final resp = await _dio.get(
        url,
        options: Options(headers: {'Authorization': token}),
      );
      return resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('generateInviteCode error: $e');
    }
    return false;
  }

  Future<bool> transferCommission(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return false;
    final url = '$apiBase/api/v1/user/invite/transfer';

    try {
      final resp = await _dio.post(
        url,
        data: FormData.fromMap({'amount': amount}),
        options: Options(headers: {'Authorization': token}),
      );
      return resp.statusCode == 200 && resp.data['data'] == true;
    } catch (e) {
      if (kDebugMode) print('transferCommission error: $e');
    }
    return false;
  }

  Future<bool> withdrawCommission(
    double amount,
    String method,
    String account,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return false;
    final url = '$apiBase/api/v1/user/invite/withdraw';

    try {
      final resp = await _dio.post(
        url,
        data: FormData.fromMap({
          'amount': amount,
          'withdraw_method': method,
          'withdraw_account': account,
        }),
        options: Options(headers: {'Authorization': token}),
      );
      return resp.statusCode == 200 && resp.data['data'] == true;
    } catch (e) {
      if (kDebugMode) print('withdrawCommission error: $e');
    }
    return false;
  }

  // --- Deposit Method ---

  Future<String?> submitDepositOrder(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return null;
    final url = '$apiBase/api/v1/user/order/save';

    try {
      final data = {
        'plan_id': 0,
        'deposit_amount': amount,
        'period': 'deposit',
      };

      final resp = await _dio.post(
        url,
        data: data,
        options: Options(
          headers: {'Authorization': token, 'Content-Type': 'application/json'},
        ),
      );

      if (resp.statusCode == 200 && resp.data['data'] != null) {
        final responseData = resp.data['data'];
        if (responseData is String) return responseData;
        if (responseData is Map && responseData['trade_no'] != null) {
          return responseData['trade_no'].toString();
        }
      }
    } catch (e) {
      if (kDebugMode) print('submitDepositOrder error: $e');
      if (e is DioException) {
        final msg = e.response?.data['message'];
        if (msg != null) throw msg;
      }
    }
    return null;
  }

  /// 获取订阅信息（包含实时流量: u, d, transfer_enable）
  Future<Map<String, dynamic>?> getSubscriptionData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('v2board_token');
    final apiBase =
        prefs.getString('v2board_api_base') ?? await _getWorkingApiBase();

    if (token == null || apiBase == null) return null;
    final url = '$apiBase/api/v1/user/getSubscribe';

    try {
      final resp = await _dio.get(
        url,
        options: Options(headers: {'Authorization': token}),
      );
      if (resp.statusCode == 200 &&
          resp.data != null &&
          resp.data['data'] != null) {
        return Map<String, dynamic>.from(resp.data['data']);
      }
    } catch (e) {
      if (kDebugMode) print('V2Board getSubscriptionData error: $e');
    }
    return null;
  }

  /// 通过订阅链接 Header 获取流量信息 (Subscription-Userinfo)
  Future<Map<String, dynamic>?> fetchTrafficFromSubscriptionUrl() async {
    final subUrl = await getSubscribeUrl();
    if (subUrl == null) return null;
    try {
      Response resp;
      try {
        resp = await _dio.head(subUrl);
      } catch (e) {
        resp = await _dio.get(subUrl);
      }

      final header = resp.headers.value('subscription-userinfo');
      // format: upload=123; download=456; total=789; expire=123456
      if (header != null) {
        final data = <String, dynamic>{};
        final parts = header.split(';');
        for (final part in parts) {
          final kv = part.trim().split('=');
          if (kv.length == 2) {
            final key = kv[0].trim().toLowerCase();
            final value = int.tryParse(kv[1].trim()) ?? 0;
            if (key == 'upload') data['u'] = value;
            if (key == 'download') data['d'] = value;
            if (key == 'total') data['transfer_enable'] = value;
            if (key == 'expire') data['expired_at'] = value;
          }
        }
        if (data.isNotEmpty) return data;
      }
    } catch (e) {
      if (kDebugMode) print('fetchTrafficFromSubscriptionUrl error: $e');
    }
    return null;
  }
}
