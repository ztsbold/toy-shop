import 'package:flutter/foundation.dart';

import '../../../../data/repositories/shop_repository.dart';
import '../../../../domain/models/toy.dart';

enum ToySort { featured, priceAsc, priceDesc }

extension ToySortLabel on ToySort {
  String get label => switch (this) {
        ToySort.featured => 'Онцлох эхэнд',
        ToySort.priceAsc => 'Үнэ өсөхөөр',
        ToySort.priceDesc => 'Үнэ буурахаар',
      };
}

class CatalogViewModel extends ChangeNotifier {
  CatalogViewModel({required ShopRepository repository})
      : _repository = repository;

  final ShopRepository _repository;

  List<Toy> _all = [];
  bool _loading = false;
  String? _error;
  String _query = '';
  String? _category;
  ToySort _sort = ToySort.featured;

  bool get loading => _loading;
  String? get error => _error;
  String? get selectedCategory => _category;
  String get query => _query;
  ToySort get sort => _sort;
  List<Toy> get all => _all;
  bool get isFiltering => _query.isNotEmpty || _category != null;

  /// Ангилал бүр ба түүний барааны тоо (гарч ирсэн дарааллаар)
  Map<String, int> get categoryCounts {
    final m = <String, int>{};
    for (final t in _all) {
      if (t.category.isEmpty) continue;
      m[t.category] = (m[t.category] ?? 0) + 1;
    }
    return m;
  }

  List<String> get categories => categoryCounts.keys.toList();

  List<Toy> get toys {
    final q = _query.toLowerCase();
    final list = _all.where((t) {
      final okCat = _category == null || t.category == _category;
      final okQuery = q.isEmpty ||
          t.name.toLowerCase().contains(q) ||
          t.subtitle.toLowerCase().contains(q) ||
          t.sku.toLowerCase().contains(q);
      return okCat && okQuery;
    }).toList();
    switch (_sort) {
      case ToySort.priceAsc:
        list.sort((a, b) => a.price.compareTo(b.price));
      case ToySort.priceDesc:
        list.sort((a, b) => b.price.compareTo(a.price));
      case ToySort.featured:
        break; // сервер "ШИНЭ"-г эхэнд нь өгдөг
    }
    return list;
  }

  List<Toy> byCategory(String c) =>
      _all.where((t) => t.category == c).toList();

  List<Toy> byIds(Set<String> ids) =>
      _all.where((t) => ids.contains(t.id)).toList();

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _all = await _repository.getToys();
    } catch (e) {
      _error = 'Бараа ачаалж чадсангүй. Интернэтээ шалгаад дахин оролдоно уу.';
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
    _category = (c == _category) ? null : c;
    notifyListeners();
  }

  void setSort(ToySort s) {
    _sort = s;
    notifyListeners();
  }
}
