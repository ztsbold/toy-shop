import '../../domain/models/cart_item.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/delivery_info.dart';
import '../../domain/models/order_result.dart';
import '../../domain/models/order_summary.dart';
import '../../domain/models/shop_config.dart';
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

  Future<ShopConfig> getConfig() => _api.fetchConfig();

  Future<OrderResult> placeOrder(List<CartItem> items, DeliveryInfo delivery,
      String deliveryOptionId,
      {int pointsToUse = 0}) async {
    final result = await _api.createOrder(
        items: items,
        delivery: delivery,
        deliveryOptionId: deliveryOptionId,
        pointsToUse: pointsToUse);
    await _store.saveDelivery(delivery);
    // Нэвтэрсэн хэрэглэгчийн захиалга серверт бүртгэлтэй тул утсанд хадгалахгүй.
    // Зөвхөн зочноор (нэвтрэлгүй) өгсөн захиалгыг энэ утсанд санана.
    if (!isLoggedIn) await _store.addOrderId(result.orderId);
    return result;
  }

  Future<bool> isPaid(String orderId, {bool providerCheck = false}) async =>
      (await _api.fetchOrderSummary(orderId, providerCheck: providerCheck))
          .isPaid;

  Future<DeliveryInfo?> lastDelivery() => _store.loadDelivery();

  Future<Set<String>> favorites() => _store.loadFavorites();
  Future<void> saveFavorites(Set<String> ids) => _store.saveFavorites(ids);

  Future<OrderSummary> orderSummary(String id) => _api.fetchOrderSummary(id);

  // ---------- Нэвтрэлт ----------
  bool get isLoggedIn => _api.token != null;

  /// Хадгалсан токеноор нэвтрэх. Хүчингүй бол устгаж null буцаана.
  Future<Customer?> restoreSession() async {
    await _store.runOneTimeCleanup();
    final t = await _store.loadToken();
    if (t == null) return null;
    _api.token = t;
    try {
      return await _api.fetchMe();
    } on ApiException catch (e) {
      if (e.isUnauthorized) await logout();
      rethrow;
    }
  }

  Future<int> requestOtp(String email) => _api.requestOtp(email);

  Future<AuthResult> verifyOtp(String email, String code) async {
    final r = await _api.verifyOtp(email, code);
    _api.token = r.token;
    await _store.saveToken(r.token);
    return r;
  }

  Future<void> cancelMyOrder(String orderId) => _api.cancelMyOrder(orderId);

  Future<void> deleteAccount() async {
    await _api.deleteAccount();
    await logout();
  }

  Future<void> logout() async {
    _api.token = null;
    await _store.saveToken(null);
    await _store.clearPersonal();
  }

  Future<Customer> me() => _api.fetchMe();
  Future<Customer> updateProfile(String name, String phone) =>
      _api.updateProfile(name, phone);
  Future<List<OrderSummary>> serverOrders() => _api.fetchMyOrders();
  Future<List<PointsEntry>> pointsHistory() => _api.fetchPoints();
  Future<List<AppNotification>> notifications() => _api.fetchNotifications();
  Future<void> markNotificationsRead() => _api.markNotificationsRead();

  /// Энэ утаснаас өгсөн захиалгууд (олдохгүй болсныг алгасна)
  Future<List<OrderSummary>> myOrders() async {
    await _store.runOneTimeCleanup();
    final ids = await _store.loadOrderIds();
    final results = await Future.wait(ids.map((id) async {
      try {
        return await _api.fetchOrderSummary(id);
      } catch (_) {
        return null;
      }
    }));
    return results.whereType<OrderSummary>().toList();
  }
}
