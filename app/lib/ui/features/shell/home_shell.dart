import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/view_models/auth_view_model.dart';
import '../catalog/view_models/catalog_view_model.dart';
import '../config/shop_config_view_model.dart';

import '../account/account_screen.dart';
import '../categories/categories_screen.dart';
import '../favorites/views/favorites_screen.dart';
import '../home/home_screen.dart';
import '../more/more_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Доод цэсний табыг кодоос солих: HomeShell.of(context)?.selectTab(1)
  static HomeShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>();

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  // Бүртгэл табыг нээх бүрт захиалгыг шинэчлэх
  final _accountKey = GlobalKey<AccountScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Апп руу буцаж ороход оноо, мессеж, үнийг шинэчлэх
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    context.read<AuthViewModel>().refresh();
    context.read<ShopConfigViewModel>().load();
    final catalog = context.read<CatalogViewModel>();
    if (catalog.all.isEmpty) catalog.load();
  }

  void selectTab(int i) {
    setState(() => _index = i);
    if (i == 3) _accountKey.currentState?.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomeScreen(),
          const CategoriesScreen(),
          const FavoritesScreen(),
          AccountScreen(key: _accountKey),
          const MoreScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE3E8F0)))),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: selectTab,
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Нүүр'),
            NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view),
                label: 'Ангилал'),
            NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: 'Хүслүүд'),
            NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Бүртгэл'),
            NavigationDestination(
                icon: Icon(Icons.more_horiz), label: 'Бусад'),
          ],
        ),
      ),
    );
  }
}
