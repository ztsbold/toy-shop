import 'package:flutter/foundation.dart';

import '../../../../data/repositories/shop_repository.dart';
import '../../../../data/services/api_service.dart';
import '../../../../domain/models/customer.dart';

/// Нэвтэрсэн хэрэглэгч, оноо, уншаагүй мессежийн тоо
class AuthViewModel extends ChangeNotifier {
  AuthViewModel({required ShopRepository repository})
      : _repository = repository;

  final ShopRepository _repository;
  Customer? _customer;
  bool _ready = false;

  Customer? get customer => _customer;
  bool get isLoggedIn => _customer != null;
  bool get ready => _ready;
  int get points => _customer?.points ?? 0;
  int get unread => _customer?.unread ?? 0;

  Future<void> init() async {
    try {
      _customer = await _repository.restoreSession();
    } catch (_) {
      // Сүлжээгүй үед дараа refresh() хийнэ
    }
    _ready = true;
    notifyListeners();
  }

  /// Оноо, мессежийн тоог шинэчлэх
  Future<void> refresh() async {
    if (!_repository.isLoggedIn) return;
    try {
      _customer = await _repository.me();
      notifyListeners();
    } on ApiException catch (e) {
      if (e.isUnauthorized) await logout();
    } catch (_) {}
  }

  Future<int> requestOtp(String phone) => _repository.requestOtp(phone);

  /// Амжилттай бол шинэ хэрэглэгч эсэхийг буцаана
  Future<bool> verify(String phone, String code) async {
    final r = await _repository.verifyOtp(phone, code);
    _customer = r.customer;
    notifyListeners();
    return r.isNew || r.customer.name.isEmpty;
  }

  Future<void> updateName(String name) async {
    _customer = await _repository.updateName(name);
    notifyListeners();
  }

  void clearUnread() {
    final c = _customer;
    if (c == null) return;
    _customer = Customer(id: c.id, phone: c.phone, name: c.name, points: c.points);
    notifyListeners();
  }

  Future<void> logout() async {
    await _repository.logout();
    _customer = null;
    notifyListeners();
  }
}
