import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../auth/view_models/auth_view_model.dart';
import '../auth/views/login_screen.dart';
import '../catalog/view_models/catalog_view_model.dart';
import '../notifications/notifications_screen.dart';
import '../config/shop_config_view_model.dart';
import '../shell/home_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(BuildContext context) => Future.wait([
        context.read<CatalogViewModel>().load(),
        context.read<ShopConfigViewModel>().load(),
      ]);

  void _showSort(BuildContext context) {
    final vm = context.read<CatalogViewModel>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Эрэмбэлэх',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          for (final s in ToySort.values)
            ListTile(
              title: Text(s.label),
              trailing: vm.sort == s
                  ? const Icon(Icons.check, color: AppColors.blue)
                  : null,
              onTap: () {
                vm.setSort(s);
                Navigator.pop(ctx);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CatalogViewModel>();
    final toys = vm.toys;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => _refresh(context),
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 4, 0),
                child: Row(children: [
                  Expanded(child: BrandHeader()),
                  _BellButton(),
                  CartButton(),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: TextField(
                  onChanged: vm.search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Тоглоом хайх...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                    suffixIcon: IconButton(
                      tooltip: 'Эрэмбэлэх',
                      onPressed: () => _showSort(context),
                      icon: const Icon(Icons.tune, color: AppColors.ink),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.line),
                    ),
                  ),
                ),
              ),
            ),
            if (vm.categories.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Ангилалууд',
                  actionLabel: 'Бүгдийг үзэх',
                  onAction: () => HomeShell.of(context)?.selectTab(1),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 112,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: [
                      for (final c in vm.categories)
                        CategoryBubble(
                          label: c,
                          selected: vm.selectedCategory == c,
                          onTap: () => vm.selectCategory(c),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: SectionHeader(
                title: vm.isFiltering
                    ? 'Илэрц: ${toys.length}'
                    : 'Онцлох бүтээгдэхүүн',
                actionLabel: vm.selectedCategory != null ? 'Цэвэрлэх' : null,
                onAction: () => vm.selectCategory(null),
              ),
            ),
            if (vm.loading && vm.all.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Ачаалж байна...\nАнх нээхэд түр хугацаа шаардагдаж магадгүй.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted)),
                  ]),
                ),
              )
            else if (vm.error != null && vm.all.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.wifi_off,
                  message: vm.error!,
                  actionLabel: 'Дахин оролдох',
                  onAction: () => _refresh(context),
                ),
              )
            else if (toys.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                    icon: Icons.search_off, message: 'Тоглоом олдсонгүй'),
              )
            else
              ProductGrid(toys: toys),
          ],
        ),
      ),
    );
  }
}


class _BellButton extends StatelessWidget {
  const _BellButton();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    return IconButton(
      tooltip: 'Мессежүүд',
      onPressed: () async {
        if (!auth.isLoggedIn && !await showLogin(context)) return;
        if (!context.mounted) return;
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      },
      icon: Badge(
        isLabelVisible: auth.unread > 0,
        smallSize: 9,
        backgroundColor: AppColors.blue,
        child: const Icon(Icons.notifications_none, size: 28, color: AppColors.ink),
      ),
    );
  }
}
