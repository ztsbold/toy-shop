import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'data/repositories/shop_repository.dart';
import 'data/services/api_service.dart';
import 'data/services/local_store.dart';
import 'ui/core/theme.dart';
import 'ui/features/cart/view_models/cart_view_model.dart';
import 'ui/features/catalog/views/catalog_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => ApiService(baseUrl: apiBaseUrl)),
        Provider(create: (_) => LocalStore()),
        Provider(
          create: (c) => ShopRepository(
            api: c.read<ApiService>(),
            store: c.read<LocalStore>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => CartViewModel()),
      ],
      child: const ToyShopApp(),
    ),
  );
}

class ToyShopApp extends StatelessWidget {
  const ToyShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Тоглоомын дэлгүүр',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const CatalogScreen(),
    );
  }
}
