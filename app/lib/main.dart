import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'data/repositories/shop_repository.dart';
import 'data/services/api_service.dart';
import 'data/services/local_store.dart';
import 'ui/core/theme.dart';
import 'ui/features/auth/view_models/auth_view_model.dart';
import 'ui/features/cart/view_models/cart_view_model.dart';
import 'ui/features/catalog/view_models/catalog_view_model.dart';
import 'ui/features/config/shop_config_view_model.dart';
import 'ui/features/favorites/view_models/favorites_view_model.dart';
import 'ui/features/shell/home_shell.dart';

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
        ChangeNotifierProvider(
          lazy: false,
          create: (c) =>
              AuthViewModel(repository: c.read<ShopRepository>())..init(),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (c) =>
              CatalogViewModel(repository: c.read<ShopRepository>())..load(),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (c) =>
              ShopConfigViewModel(repository: c.read<ShopRepository>())..load(),
        ),
        ChangeNotifierProvider(
          lazy: false,
          create: (c) =>
              FavoritesViewModel(repository: c.read<ShopRepository>())..load(),
        ),
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
      title: '$brandMark $brandName',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      home: const HomeShell(),
    );
  }
}
