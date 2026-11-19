import 'package:flutter/foundation.dart';

import '../../../../data/repositories/shop_repository.dart';

class FavoritesViewModel extends ChangeNotifier {
  FavoritesViewModel({required ShopRepository repository})
      : _repository = repository;

  final ShopRepository _repository;
  Set<String> _ids = {};

  Set<String> get ids => _ids;
  bool contains(String id) => _ids.contains(id);

  Future<void> load() async {
    _ids = await _repository.favorites();
    notifyListeners();
  }

  /// Нэмэгдсэн бол true
  bool toggle(String id) {
    final added = !_ids.contains(id);
    _ids = {..._ids};
    if (added) {
      _ids.add(id);
    } else {
      _ids.remove(id);
    }
    notifyListeners();
    _repository.saveFavorites(_ids);
    return added;
  }
}
