import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/shop_repository.dart';
import '../../../../domain/models/order_result.dart';

class PaymentViewModel extends ChangeNotifier {
  PaymentViewModel({required ShopRepository repository, required this.order})
      : _repository = repository;

  final ShopRepository _repository;
  final OrderResult order;

  Timer? _timer;
  bool _paid = false;
  bool _checking = false;
  String? _message;

  bool get paid => _paid;
  bool get checking => _checking;
  String? get message => _message;

  /// 5 секунд тутам төлбөрийн төлөв шалгана (30 минут хүртэл).
  void startPolling() {
    _timer?.cancel();
    final startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (DateTime.now().difference(startedAt).inMinutes >= 30) {
        t.cancel();
        return;
      }
      check(silent: true);
    });
  }

  Future<void> check({bool silent = false}) async {
    if (_paid || _checking) return;
    _checking = true;
    if (!silent) {
      _message = null;
      notifyListeners();
    }
    try {
      _paid = await _repository.isPaid(order.orderId, providerCheck: !silent);
      if (_paid) {
        _timer?.cancel();
      } else if (!silent) {
        _message = 'Төлбөр хараахан ороогүй байна.';
      }
    } catch (e) {
      if (!silent) _message = 'Шалгаж чадсангүй: $e';
    } finally {
      _checking = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
