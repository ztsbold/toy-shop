import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/delivery_info.dart';

/// Хүргэлтийн мэдээллийг дараагийн захиалгад автоматаар бөглөхөөр хадгална.
class LocalStore {
  static const _deliveryKey = 'last_delivery_info';

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
}
