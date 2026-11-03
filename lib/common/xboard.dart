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
  Future<BrandConfig> loadConfig() async {
    final preferences = await SharedPreferences.getInstance();
    for (final url in splitBrandUrls(brandConfigUrls)) {
      try {
        final response = await _dio.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 6),
          ),
        );
        final body = response.data ?? '';
        final config = BrandConfig.fromJson(
          json.decode(body) as Map<String, Object?>,
        );
        await preferences.setString(_configKey, body);
        return config;
      } catch (e) {
        commonPrint.log(
          'brand config $url: ${compactError(e)}',
          logLevel: LogLevel.warning,
        );
      }
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

  /// Tries the last address that answered, then the rest in order. An answer
  /// from the panel, error or not, ends the search: only an unreachable
  /// address moves on to the next.
  Future<Object?> _request(
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
        return body is Map ? body['data'] : null;
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
