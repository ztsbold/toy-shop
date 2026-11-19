import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/cart_item.dart';
import '../../domain/models/delivery_info.dart';
import '../../domain/models/order_result.dart';
import '../../domain/models/toy.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ApiService {
  ApiService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const _jsonHeaders = {
    'Content-Type': 'application/json; charset=UTF-8',
    'Accept': 'application/json',
  };

  Future<List<Toy>> fetchToys() async {
    final res = await _client
        .get(Uri.parse('$baseUrl/api/toys'), headers: _jsonHeaders)
        // Үнэгүй сервер унтсан бол сэрэхэд ~1 минут зарцуулна
        .timeout(const Duration(seconds: 90));
    _ensureOk(res);
    final list = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    return list.cast<Map<String, dynamic>>().map(Toy.fromJson).toList();
  }

  Future<OrderResult> createOrder({
    required List<CartItem> items,
    required DeliveryInfo delivery,
  }) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/api/orders'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'items': items.map((e) => e.toOrderJson()).toList(),
            'delivery': delivery.toJson(),
          }),
        )
        .timeout(const Duration(seconds: 90));
    _ensureOk(res);
    return OrderResult.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  /// "PENDING" эсвэл "PAID"
  Future<String> fetchOrderStatus(String orderId) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/api/orders/$orderId/status'),
            headers: _jsonHeaders)
        .timeout(const Duration(seconds: 30));
    _ensureOk(res);
    final body =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return body['status'] as String;
  }

  void _ensureOk(http.Response res) {
    if (res.statusCode == 200 || res.statusCode == 201) return;
    String msg = 'Серверийн алдаа (${res.statusCode})';
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['error'] is String) msg = body['error'] as String;
    } catch (_) {}
    throw ApiException(msg);
  }
}
