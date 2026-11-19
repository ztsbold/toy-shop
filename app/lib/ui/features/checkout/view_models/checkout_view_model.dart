import 'package:flutter/foundation.dart';

import '../../../../data/repositories/shop_repository.dart';
import '../../../../domain/models/cart_item.dart';
import '../../../../domain/models/delivery_info.dart';
import '../../../../domain/models/order_result.dart';

class CheckoutViewModel extends ChangeNotifier {
  CheckoutViewModel({required ShopRepository repository})
      : _repository = repository;

  final ShopRepository _repository;

  bool _submitting = false;
  String? _error;
  DeliveryInfo? _saved;

  bool get submitting => _submitting;
  String? get error => _error;
  DeliveryInfo? get savedDelivery => _saved;

  Future<void> loadSaved() async {
    _saved = await _repository.lastDelivery();
    notifyListeners();
  }

  Future<OrderResult?> submit(
      List<CartItem> items, DeliveryInfo delivery) async {
    _submitting = true;
    _error = null;
    notifyListeners();
    try {
      return await _repository.placeOrder(items, delivery);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }
}
