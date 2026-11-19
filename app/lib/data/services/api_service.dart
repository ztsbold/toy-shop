import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/cart_item.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/delivery_info.dart';
import '../../domain/models/order_result.dart';
import '../../domain/models/order_summary.dart';
import '../../domain/models/shop_config.dart';
import '../../domain/models/toy.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode = 0, this.retryAfter});
  final String message;
  final int statusCode;
  final int? retryAfter;
  bool get isUnauthorized => statusCode == 401;
  @override
  String toString() => message;
}

class ApiService {
  ApiService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  /// Нэвтэрсэн хэрэглэгчийн токен (байхгүй бол null)
  String? token;

  // Үнэгүй сервер унтсан бол сэрэхэд ~1 минут зарцуулна
  static const _slow = Duration(seconds: 90);
  static const _fast = Duration(seconds: 30);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _get(String path, [Duration timeout = _fast]) async {
    final res = await _client
        .get(Uri.parse('$baseUrl$path'), headers: _headers)
        .timeout(timeout);
    return _decode(res);
  }

  Future<dynamic> _send(String method, String path, Object? body,
      [Duration timeout = _fast]) async {
    final uri = Uri.parse('$baseUrl$path');
    final encoded = jsonEncode(body ?? const {});
    final res = await (method == 'PATCH'
            ? _client.patch(uri, headers: _headers, body: encoded)
            : _client.post(uri, headers: _headers, body: encoded))
        .timeout(timeout);
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return text.isEmpty ? null : jsonDecode(text);
    }
    String msg = 'Серверийн алдаа (${res.statusCode})';
    int? retry;
    try {
      final body = jsonDecode(text);
      if (body is Map && body['error'] is String) msg = body['error'] as String;
      if (body is Map && body['retryAfter'] is num) {
        retry = (body['retryAfter'] as num).toInt();
      }
    } catch (_) {}
    throw ApiException(msg, statusCode: res.statusCode, retryAfter: retry);
  }

  // ---------- Дэлгүүр ----------
  Future<List<Toy>> fetchToys() async {
    final list = await _get('/api/toys', _slow) as List<dynamic>;
    return list
        .cast<Map<String, dynamic>>()
        .map((j) => Toy.fromJson(j, baseUrl: baseUrl))
        .toList();
  }

  Future<ShopConfig> fetchConfig() async => ShopConfig.fromJson(
      await _get('/api/config', _slow) as Map<String, dynamic>);

  Future<OrderResult> createOrder({
    required List<CartItem> items,
    required DeliveryInfo delivery,
    required String deliveryOptionId,
    int pointsToUse = 0,
  }) async =>
      OrderResult.fromJson(await _send(
          'POST',
          '/api/orders',
          {
            'items': items.map((e) => e.toOrderJson()).toList(),
            'delivery': delivery.toJson(),
            'deliveryOptionId': deliveryOptionId,
            'pointsToUse': pointsToUse,
          },
          _slow) as Map<String, dynamic>);

  Future<OrderSummary> fetchOrderSummary(String orderId) async =>
      OrderSummary.fromJson(
          await _get('/api/orders/$orderId/status') as Map<String, dynamic>);

  // ---------- Нэвтрэлт ----------
  /// Дахин код авах хүртэл хүлээх секунд
  Future<int> requestOtp(String phone) async {
    final r = await _send('POST', '/api/auth/request-otp', {'phone': phone},
        _slow) as Map<String, dynamic>;
    return (r['retryAfter'] as num? ?? 60).toInt();
  }

  Future<AuthResult> verifyOtp(String phone, String code) async {
    final r = await _send('POST', '/api/auth/verify',
        {'phone': phone, 'code': code}) as Map<String, dynamic>;
    return AuthResult(
      token: r['token'] as String,
      customer: Customer.fromJson(r['customer'] as Map<String, dynamic>),
      isNew: r['isNew'] == true,
    );
  }

  Future<Customer> fetchMe() async =>
      Customer.fromJson(await _get('/api/me', _slow) as Map<String, dynamic>);

  Future<Customer> updateName(String name) async => Customer.fromJson(
      await _send('PATCH', '/api/me', {'name': name}) as Map<String, dynamic>);

  Future<List<OrderSummary>> fetchMyOrders() async =>
      ((await _get('/api/me/orders')) as List)
          .cast<Map<String, dynamic>>()
          .map(OrderSummary.fromJson)
          .toList();

  Future<List<PointsEntry>> fetchPoints() async =>
      ((await _get('/api/me/points')) as List)
          .cast<Map<String, dynamic>>()
          .map(PointsEntry.fromJson)
          .toList();

  Future<List<AppNotification>> fetchNotifications() async =>
      ((await _get('/api/me/notifications')) as List)
          .cast<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList();

  Future<void> markNotificationsRead() async =>
      _send('POST', '/api/me/notifications/read', null);
}
