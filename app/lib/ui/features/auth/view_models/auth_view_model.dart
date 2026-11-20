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

  /// Нэр, утас дутуу бол профайл бөглөх шаардлагатай
  bool get needsProfile => _customer != null && !_customer!.profileComplete;

  Future<int> requestOtp(String email) => _repository.requestOtp(email);

  /// Амжилттай бол профайл бөглөх шаардлагатай эсэхийг буцаана
  Future<bool> verify(String email, String code) async {
    final r = await _repository.verifyOtp(email, code);
    _customer = r.customer;
    notifyListeners();
    return r.needsProfile;
  }

  Future<void> updateProfile(String name, String phone) async {
    _customer = await _repository.updateProfile(name, phone);
    notifyListeners();
  }

  void clearUnread() {
    final c = _customer;
    if (c == null) return;
    _customer = c.copyWith(unread: 0);
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await _repository.deleteAccount();
    _customer = null;
    notifyListeners();
  }

  Future<void> logout() async {
    await _repository.logout();
    _customer = null;
    notifyListeners();
  }
}
