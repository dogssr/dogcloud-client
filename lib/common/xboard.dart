import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/brand.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/account.dart';
import 'package:shared_preferences/shared_preferences.dart';

class XboardException implements Exception {
  const XboardException(this.message, {this.unauthorized = false});

  final String message;

  /// The panel no longer accepts the saved login.
  final bool unauthorized;

  @override
  String toString() => message;
}

class XboardClient {
  XboardClient({required String userAgent})
    : _dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'User-Agent': userAgent},
        ),
      );

  final Dio _dio;

  static const _configKey = 'account.brandConfig';
  static const _apiKey = 'account.apiUrl';

  /// Remote config first; a cached copy, then the build defaults, when no
  /// mirror answers.
  /// The first config mirror that answers, with its raw body for caching.
  static Future<({BrandConfig config, String body})?> fetchConfig(
    Dio dio,
  ) async {
    for (final url in splitBrandUrls(brandConfigUrls)) {
      try {
        final response = await dio.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 6),
            // The COS bucket's hotlink rule turns away requests without one.
            headers: {'Referer': '$brandSiteUrl/'},
          ),
        );
        final body = response.data ?? '';
        final config = BrandConfig.fromJson(
          json.decode(body) as Map<String, Object?>,
        );
        return (config: config, body: body);
      } catch (e) {
        commonPrint.log(
          'brand config $url: ${compactError(e)}',
          logLevel: LogLevel.warning,
        );
      }
    }
    return null;
  }

  Future<BrandConfig> loadConfig() async {
    final preferences = await SharedPreferences.getInstance();
    if (await fetchConfig(_dio) case (:final config, :final body)) {
      await preferences.setString(_configKey, body);
      return config;
    }
    final cached = preferences.getString(_configKey);
    if (cached != null) {
      try {
        return BrandConfig.fromJson(
          json.decode(cached) as Map<String, Object?>,
        );
      } catch (_) {}
    }
    return BrandConfig.defaults;
  }

  Future<String> login(
    BrandConfig config, {
    required String email,
    required String password,
  }) async {
    final data = await _request(
      config,
      (base) => _dio.post<Object?>(
        '$base/passport/auth/login',
        data: {'email': email, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      ),
    );
    final authData = data is Map ? data['auth_data'] as String? : null;
    if (authData == null || authData.isEmpty) {
      throw const XboardException('登录失败，请稍后重试');
    }
    return authData;
  }

  Future<AccountSubscription> subscription(
    BrandConfig config,
    String authData,
  ) async {
    final data = await _request(
      config,
      (base) => _dio.get<Object?>(
        '$base/user/getSubscribe',
        options: Options(headers: {'Authorization': authData}),
      ),
    );
    if (data is! Map<String, Object?>) {
      throw const XboardException('账户信息读取失败，请稍后重试');
    }
    return AccountSubscription.fromJson(data);
  }

  Future<List<AccountNotice>> notices(
    BrandConfig config,
    String authData,
  ) async {
    final data = await _request(
      config,
      (base) => _dio.get<Object?>(
        '$base/user/notice/fetch',
        options: Options(headers: {'Authorization': authData}),
      ),
    );
    return [
      for (final item in data is List ? data : const [])
        if (item is Map<String, Object?>) AccountNotice.fromJson(item),
    ];
  }

  Future<GuestConfig> guestConfig(BrandConfig config) async {
    final data = await _request(
      config,
      (base) => _dio.get<Object?>('$base/guest/comm/config'),
    );
    if (data is! Map<String, Object?>) {
      throw const XboardException('无法读取注册设置，请稍后重试');
    }
    return GuestConfig.fromJson(data);
  }

  Future<void> sendEmailCode(
    BrandConfig config, {
    required String email,
    String? captchaToken,
  }) async {
    await _request(
      config,
      (base) => _dio.post<Object?>(
        '$base/passport/comm/sendEmailVerify',
        data: {'email': email, 'turnstile_token': ?captchaToken},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      ),
    );
  }

  /// Returns the new account's auth data; the panel signs it in on sign-up.
  Future<String> register(
    BrandConfig config, {
    required String email,
    required String password,
    required String emailCode,
    String? inviteCode,
    String? captchaToken,
  }) async {
    final data = await _request(
      config,
      (base) => _dio.post<Object?>(
        '$base/passport/auth/register',
        data: {
          'email': email,
          'password': password,
          'email_code': emailCode,
          if (inviteCode != null && inviteCode.isNotEmpty)
            'invite_code': inviteCode,
          'turnstile_token': ?captchaToken,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      ),
    );
    final authData = data is Map ? data['auth_data'] as String? : null;
    if (authData == null || authData.isEmpty) {
      throw const XboardException('注册失败，请稍后重试');
    }
    return authData;
  }

  Future<void> resetPassword(
    BrandConfig config, {
    required String email,
    required String emailCode,
    required String password,
  }) async {
    await _request(
      config,
      (base) => _dio.post<Object?>(
        '$base/passport/auth/forget',
        data: {'email': email, 'email_code': emailCode, 'password': password},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      ),
    );
  }

  Future<List<GuideArticle>> guides(BrandConfig config, String authData) async {
    final data = await _request(
      config,
      (base) => _dio.get<Object?>(
        '$base/user/knowledge/fetch',
        queryParameters: {'language': 'zh-CN'},
        options: _auth(authData),
      ),
    );
    return [
      if (data is Map)
        for (final items in data.values)
          for (final item in items is List ? items : const [])
            if (item is Map<String, Object?>) GuideArticle.fromJson(item),
    ];
  }

  Future<GuideArticle> guide(
    BrandConfig config,
    String authData,
    int id,
  ) async {
    final data = await _request(
      config,
      (base) => _dio.get<Object?>(
        '$base/user/knowledge/fetch',
        queryParameters: {'id': id},
        options: _auth(authData),
      ),
    );
    if (data is! Map<String, Object?>) {
      throw const XboardException('文章不存在');
    }
    return GuideArticle.fromJson(data);
  }

  Future<List<AccountTicket>> tickets(
    BrandConfig config,
    String authData,
  ) async {
    final data = await _request(
      config,
      (base) => _dio.get<Object?>(
        '$base/user/ticket/fetch',
        options: _auth(authData),
      ),
    );
    return [
      for (final item in data is List ? data : const [])
        if (item is Map<String, Object?>) AccountTicket.fromJson(item),
    ];
  }

  Future<AccountTicket> ticket(
    BrandConfig config,
    String authData,
    int id,
  ) async {
    final data = await _request(
      config,
      (base) => _dio.get<Object?>(
        '$base/user/ticket/fetch',
        queryParameters: {'id': id},
        options: _auth(authData),
      ),
    );
    if (data is! Map<String, Object?>) {
      throw const XboardException('工单不存在');
    }
    return AccountTicket.fromJson(data);
  }

  Future<void> createTicket(
    BrandConfig config,
    String authData, {
    required String subject,
    required String message,
  }) async {
    await _request(
      config,
      (base) => _dio.post<Object?>(
        '$base/user/ticket/save',
        data: {'subject': subject, 'level': 1, 'message': message},
        options: _auth(authData, form: true),
      ),
    );
  }

  Future<void> replyTicket(
    BrandConfig config,
    String authData, {
    required int id,
    required String message,
  }) async {
    await _request(
      config,
      (base) => _dio.post<Object?>(
        '$base/user/ticket/reply',
        data: {'id': id, 'message': message},
        options: _auth(authData, form: true),
      ),
    );
  }

  Future<void> closeTicket(BrandConfig config, String authData, int id) async {
    await _request(
      config,
      (base) => _dio.post<Object?>(
        '$base/user/ticket/close',
        data: {'id': id},
        options: _auth(authData, form: true),
      ),
    );
  }

  Future<InviteInfo> invite(BrandConfig config, String authData) async {
    final data = await _request(
      config,
      (base) => _dio.get<Object?>(
        '$base/user/invite/fetch',
        options: _auth(authData),
      ),
    );
    if (data is! Map<String, Object?>) {
      throw const XboardException('邀请信息读取失败');
    }
    return InviteInfo.fromJson(data);
  }

  Future<void> createInviteCode(BrandConfig config, String authData) async {
    await _request(
      config,
      (base) =>
          _dio.get<Object?>('$base/user/invite/save', options: _auth(authData)),
    );
  }

  /// Personal coupons from the panel's OpsBot plugin.
  Future<List<BrandCoupon>> coupons(BrandConfig config, String authData) async {
    final data = await _request(
      config,
      (base) => _dio.get<Object?>(
        '$base/user/opsbot/coupons',
        options: _auth(authData),
      ),
    );
    final coupons = data is Map ? data['coupons'] : null;
    return [
      for (final item in coupons is List ? coupons : const [])
        if (item is Map<String, Object?>) BrandCoupon.fromJson(item),
    ];
  }

  Future<List<AccountPlan>> plans(BrandConfig config, String authData) async {
    final data = await _request(
      config,
      (base) =>
          _dio.get<Object?>('$base/user/plan/fetch', options: _auth(authData)),
    );
    return [
      for (final item in data is List ? data : const [])
        if (item is Map<String, Object?>) AccountPlan.fromJson(item),
    ];
  }

  Future<List<PaymentMethod>> paymentMethods(
    BrandConfig config,
    String authData,
  ) async {
    final data = await _request(
      config,
      (base) => _dio.get<Object?>(
        '$base/user/order/getPaymentMethod',
        options: _auth(authData),
      ),
    );
    return [
      for (final item in data is List ? data : const [])
        if (item is Map<String, Object?>) PaymentMethod.fromJson(item),
    ];
  }

  Future<AccountCoupon> checkCoupon(
    BrandConfig config,
    String authData, {
    required String code,
    required int planId,
    required PlanPeriod period,
  }) async {
    final data = await _request(
      config,
      (base) => _dio.post<Object?>(
        '$base/user/coupon/check',
        data: {'code': code, 'plan_id': planId, 'period': period.key},
        options: _auth(authData, form: true),
      ),
    );
    if (data is! Map<String, Object?>) {
      throw const XboardException('优惠券无效');
    }
    return AccountCoupon.fromJson(data);
  }

  /// Returns the trade number of the new unpaid order.
  Future<String> saveOrder(
    BrandConfig config,
    String authData, {
    required int planId,
    required PlanPeriod period,
    String? couponCode,
  }) async {
    final data = await _request(
      config,
      (base) => _dio.post<Object?>(
        '$base/user/order/save',
        data: {
          'plan_id': planId,
          'period': period.key,
          if (couponCode != null && couponCode.isNotEmpty)
            'coupon_code': couponCode,
        },
        options: _auth(authData, form: true),
      ),
    );
    if (data is! String || data.isEmpty) {
      throw const XboardException('下单失败，请稍后重试');
    }
    return data;
  }

  /// type -1: settled without paying (balance or a free order); type 1: a
  /// payment page URL in data; type 0: a QR code payload in data.
  Future<({int type, Object? data})> checkout(
    BrandConfig config,
    String authData, {
    required String tradeNo,
    required int methodId,
  }) async {
    final body = await _requestBody(
      config,
      (base) => _dio.post<Object?>(
        '$base/user/order/checkout',
        data: {'trade_no': tradeNo, 'method': methodId},
        options: _auth(authData, form: true),
      ),
    );
    return (type: (body['type'] as num?)?.toInt() ?? 1, data: body['data']);
  }

  Future<int> orderStatus(
    BrandConfig config,
    String authData,
    String tradeNo,
  ) async {
    final data = await _request(
      config,
      (base) => _dio.get<Object?>(
        '$base/user/order/check',
        queryParameters: {'trade_no': tradeNo},
        options: _auth(authData),
      ),
    );
    return (data as num?)?.toInt() ?? 0;
  }

  Future<List<AccountOrder>> orders(BrandConfig config, String authData) async {
    final data = await _request(
      config,
      (base) =>
          _dio.get<Object?>('$base/user/order/fetch', options: _auth(authData)),
    );
    return [
      for (final item in data is List ? data : const [])
        if (item is Map<String, Object?>) AccountOrder.fromJson(item),
    ];
  }

  Future<void> cancelOrder(
    BrandConfig config,
    String authData,
    String tradeNo,
  ) async {
    await _request(
      config,
      (base) => _dio.post<Object?>(
        '$base/user/order/cancel',
        data: {'trade_no': tradeNo},
        options: _auth(authData, form: true),
      ),
    );
  }

  Future<CheckinStatus> checkinStatus(
    BrandConfig config,
    String authData,
  ) async {
    final data = await _request(
      config,
      (base) =>
          _dio.get<Object?>('$base/user/checkin', options: _auth(authData)),
    );
    if (data is! Map<String, Object?>) {
      throw const XboardException('签到功能暂不可用');
    }
    return CheckinStatus.fromJson(data);
  }

  /// The traffic it granted on success, the panel's reason otherwise.
  Future<({bool success, String message})> checkin(
    BrandConfig config,
    String authData,
  ) async {
    final body = await _requestBody(
      config,
      (base) =>
          _dio.post<Object?>('$base/user/checkin', options: _auth(authData)),
    );
    final data = body['data'];
    final success = data is Map && data['success'] == true;
    return (
      success: success,
      message: success
          ? '${data['traffic'] ?? ''}'
          : body['message'] as String? ?? '签到失败，请稍后重试',
    );
  }

  Options _auth(String authData, {bool form = false}) => Options(
    headers: {'Authorization': authData},
    contentType: form ? Headers.formUrlEncodedContentType : null,
  );

  /// Tries the last address that answered, then the rest in order. An answer
  /// from the panel, error or not, ends the search: only an unreachable
  /// address moves on to the next.
  Future<Object?> _request(
    BrandConfig config,
    Future<Response<Object?>> Function(String base) send,
  ) async {
    final body = await _requestBody(config, send);
    return body['data'];
  }

  Future<Map<Object?, Object?>> _requestBody(
    BrandConfig config,
    Future<Response<Object?>> Function(String base) send,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final last = preferences.getString(_apiKey);
    final bases = [
      if (last != null && config.apiUrls.contains(last)) last,
      ...config.apiUrls.where((base) => base != last),
    ];
    for (final base in bases) {
      try {
        final response = await send(base);
        await preferences.setString(_apiKey, base);
        final body = response.data;
        return body is Map ? body : const {};
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        final body = e.response?.data;
        if (status != null && body is Map) {
          await preferences.setString(_apiKey, base);
          throw XboardException(
            body['message'] as String? ?? '请求失败（$status）',
            unauthorized: status == 401 || status == 403,
          );
        }
        commonPrint.log(
          'panel $base: ${compactError(e)}',
          logLevel: LogLevel.warning,
        );
      }
    }
    throw const XboardException('无法连接服务器，请检查网络后重试');
  }
}
