import 'package:flutter/foundation.dart';

import '../../../data/repositories/shop_repository.dart';
import '../../../domain/models/shop_config.dart';

/// Хүргэлтийн сонголт, дэлгүүрийн утас зэргийг серверээс уншина.
/// Админ хуудаснаас өөрчлөхөд апп дахин суулгах шаардлагагүй.
class ShopConfigViewModel extends ChangeNotifier {
  ShopConfigViewModel({required ShopRepository repository})
      : _repository = repository;

  final ShopRepository _repository;
  ShopConfig _config = ShopConfig.fallback;
  bool _loaded = false;

  ShopConfig get config => _config;
  bool get loaded => _loaded;

  Future<void> load() async {
    try {
      _config = await _repository.getConfig();
      _loaded = true;
      notifyListeners();
    } catch (_) {
      // Сүлжээ алдаатай бол өмнөх утгаараа үлдээнэ
    }
  }
}
