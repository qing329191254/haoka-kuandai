import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  bool get isUnauthorized => statusCode == 401;
  @override
  String toString() => message;
}

class Api {
  Api._();

  static const _tokenKey = 'app_token';
  /// 线上接口；如需临时改地址用编译参数：--dart-define=API_BASE=...
  static const productionBase = 'https://www.lcnh-platform.cn';
  static String? token;
  static VoidCallback? onUnauthorized;
  static bool _notifyingUnauthorized = false;

  static String get base {
    const fromEnv = String.fromEnvironment('API_BASE');
    if (fromEnv.isNotEmpty) {
      return fromEnv.replaceAll(RegExp(r'/$'), '');
    }
    return productionBase;
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_tokenKey);
  }

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString(_tokenKey);
  }

  static Future<void> saveToken(String value) async {
    token = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, value);
  }

  static Future<void> clearToken() async {
    token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  static void _emitUnauthorized() {
    if (_notifyingUnauthorized) return;
    _notifyingUnauthorized = true;
    try {
      onUnauthorized?.call();
    } finally {
      _notifyingUnauthorized = false;
    }
  }

  static Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    var uri = Uri.parse('$base$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(
        queryParameters: {
          ...uri.queryParameters,
          for (final e in query.entries)
            if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
        },
      );
    }
    late http.Response res;
    try {
      final encoded = body == null ? null : jsonEncode(body);
      res = switch (method) {
        'GET' =>
          await http
              .get(uri, headers: _headers)
              .timeout(const Duration(seconds: 15)),
        'PUT' =>
          await http
              .put(uri, headers: _headers, body: encoded)
              .timeout(const Duration(seconds: 15)),
        'DELETE' =>
          await http
              .delete(uri, headers: _headers)
              .timeout(const Duration(seconds: 15)),
        _ =>
          await http
              .post(uri, headers: _headers, body: encoded)
              .timeout(const Duration(seconds: 15)),
      };
    } catch (_) {
      throw ApiException('网络异常，请确认后端已启动（$base）');
    }
    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        data = res.body;
      }
    }
    if (res.statusCode == 401) {
      await clearToken();
      _emitUnauthorized();
      throw ApiException(_detail(data, res.statusCode), statusCode: 401);
    }
    if (res.statusCode >= 400) {
      throw ApiException(_detail(data, res.statusCode), statusCode: res.statusCode);
    }
    return data;
  }

  static String _detail(dynamic data, int status) {
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] is String) return first['msg'] as String;
        if (first is String) return first;
      }
    }
    return '请求失败（$status）';
  }

  static Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send('GET', path, query: query);

  static Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);

  static Future<dynamic> put(String path, [Object? body]) =>
      _send('PUT', path, body: body);

  /// 客服 WebSocket：`wss://host/api/app/cs/ws?token=...`
  static Uri csWsUri() {
    final t = token ?? '';
    final httpBase = Uri.parse(base);
    final scheme = httpBase.scheme == 'https' ? 'wss' : 'ws';
    return httpBase.replace(
      scheme: scheme,
      path: '/api/app/cs/ws',
      queryParameters: {if (t.isNotEmpty) 'token': t},
    );
  }

  static Future<String> uploadImage(String filePath, {bool apply = false}) async {
    final path = apply ? '/api/uploads/apply-images' : '/api/uploads/images';
    final uri = Uri.parse('$base$path');
    final req = http.MultipartRequest('POST', uri);
    if (!apply && token != null && token!.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $token';
    }
    req.files.add(await http.MultipartFile.fromPath('file', filePath));
    late http.StreamedResponse streamed;
    try {
      streamed = await req.send().timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException('图片上传失败，请确认后端已启动（$base）');
    }
    final body = await streamed.stream.bytesToString();
    dynamic data;
    try {
      data = body.isEmpty ? null : jsonDecode(body);
    } catch (_) {
      data = body;
    }
    if (streamed.statusCode == 401) {
      await clearToken();
      _emitUnauthorized();
      throw ApiException(_detail(data, streamed.statusCode), statusCode: 401);
    }
    if (streamed.statusCode >= 400) {
      throw ApiException(_detail(data, streamed.statusCode), statusCode: streamed.statusCode);
    }
    final url = data is Map ? '${data['url'] ?? ''}' : '';
    if (url.isEmpty) throw ApiException('图片上传结果无效');
    return url;
  }
}
