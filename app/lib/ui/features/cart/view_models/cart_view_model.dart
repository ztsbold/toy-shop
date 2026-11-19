import 'package:flutter/foundation.dart';

import '../../../../config.dart' as config;
import '../../../../domain/models/cart_item.dart';
import '../../../../domain/models/toy.dart';

class CartViewModel extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  List<CartItem> get items => List.unmodifiable(_items.values);
  bool get isEmpty => _items.isEmpty;
  int get count => _items.values.fold(0, (s, e) => s + e.qty);
  int get subtotal => _items.values.fold(0, (s, e) => s + e.subtotal);
  int get deliveryFee =>
      isEmpty || subtotal >= config.freeDeliveryFrom ? 0 : config.deliveryFee;
  int get total => subtotal + deliveryFee;

  int qtyOf(String toyId) => _items[toyId]?.qty ?? 0;

  /// Үлдэгдлээс хэтэрвэл false буцаана.
  bool add(Toy toy, {int qty = 1}) {
    final current = qtyOf(toy.id);
    if (current + qty > toy.stock) return false;
    _items.update(toy.id, (e) => e..qty += qty,
        ifAbsent: () => CartItem(toy: toy, qty: qty));
    notifyListeners();
    return true;
  }

  void setQty(String toyId, int qty) {
    final item = _items[toyId];
    if (item == null) return;
    if (qty <= 0) {
      _items.remove(toyId);
    } else {
      item.qty = qty.clamp(1, item.toy.stock);
    }
    notifyListeners();
  }

  void remove(String toyId) {
    _items.remove(toyId);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
