import '../../domain/models/cart_item.dart';
import '../../domain/models/delivery_info.dart';
import '../../domain/models/order_result.dart';
import '../../domain/models/toy.dart';
import '../services/api_service.dart';
import '../services/local_store.dart';

class ShopRepository {
  ShopRepository({required ApiService api, required LocalStore store})
      : _api = api,
        _store = store;

  final ApiService _api;
  final LocalStore _store;

  Future<List<Toy>> getToys() => _api.fetchToys();

  Future<OrderResult> placeOrder(
      List<CartItem> items, DeliveryInfo delivery) async {
    final result = await _api.createOrder(items: items, delivery: delivery);
    await _store.saveDelivery(delivery);
    return result;
  }

  Future<bool> isPaid(String orderId) async =>
      (await _api.fetchOrderStatus(orderId)) == 'PAID';

  Future<DeliveryInfo?> lastDelivery() => _store.loadDelivery();
}
