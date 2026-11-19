import 'package:flutter/foundation.dart';

import '../../../../data/repositories/shop_repository.dart';
import '../../../../domain/models/toy.dart';

class CatalogViewModel extends ChangeNotifier {
  CatalogViewModel({required ShopRepository repository})
      : _repository = repository;

  final ShopRepository _repository;

  List<Toy> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';
  String? _category;

  bool get loading => _loading;
  String? get error => _error;
  String? get selectedCategory => _category;

  List<String> get categories =>
      _all.map((t) => t.category).where((c) => c.isNotEmpty).toSet().toList()
        ..sort();

  List<Toy> get toys => _all.where((t) {
        final okCat = _category == null || t.category == _category;
        final okQuery = _query.isEmpty ||
            t.name.toLowerCase().contains(_query.toLowerCase());
        return okCat && okQuery;
      }).toList();

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _all = await _repository.getToys();
    } catch (e) {
      _error = 'Бараа ачаалж чадсангүй. Интернэтээ шалгана уу.\n($e)';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void search(String q) {
    _query = q.trim();
    notifyListeners();
  }

  void selectCategory(String? c) {
    _category = c;
    notifyListeners();
  }
}
