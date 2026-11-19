import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/delivery_info.dart';

/// Утсан дээр хадгалах мэдээлэл: хүргэлтийн хаяг, хүслүүд, захиалгын дугаарууд.
class LocalStore {
  static const _deliveryKey = 'last_delivery_info';
  static const _favoritesKey = 'favorites';
  static const _ordersKey = 'my_orders';
  static const _tokenKey = 'auth_token';

  Future<String?> loadToken() async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

  Future<void> saveToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<DeliveryInfo?> loadDelivery() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_deliveryKey);
    if (raw == null) return null;
    try {
      return DeliveryInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDelivery(DeliveryInfo info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deliveryKey, jsonEncode(info.toJson()));
  }

  Future<Set<String>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_favoritesKey) ?? const []).toSet();
  }

  Future<void> saveFavorites(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, ids.toList());
  }

  Future<List<String>> loadOrderIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_ordersKey) ?? const [];
  }

  Future<void> addOrderId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = [id, ...(prefs.getStringList(_ordersKey) ?? const <String>[])
        .where((x) => x != id)];
    await prefs.setStringList(_ordersKey, ids.take(30).toList());
  }
}
