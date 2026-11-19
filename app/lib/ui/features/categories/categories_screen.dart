import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../catalog/view_models/catalog_view_model.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CatalogViewModel>();
    final counts = vm.categoryCounts;

    return Scaffold(
      appBar: AppBar(title: const Text('Ангилал'), actions: const [CartButton()]),
      body: counts.isEmpty
          ? EmptyState(
              icon: Icons.grid_view_outlined,
              message: vm.loading ? 'Ачаалж байна...' : 'Ангилал алга байна',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: counts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final c = counts.keys.elementAt(i);
                return Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.line),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.sky,
                      child: Icon(iconForCategory(c), color: AppColors.blue),
                    ),
                    title: Text(c,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    subtitle: Text('${counts[c]} бүтээгдэхүүн'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CategoryProductsScreen(category: c)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class CategoryProductsScreen extends StatelessWidget {
  const CategoryProductsScreen({super.key, required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    final toys = context.watch<CatalogViewModel>().byCategory(category);
    return Scaffold(
      appBar: AppBar(title: Text(category), actions: const [CartButton()]),
      body: CustomScrollView(slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ProductGrid(toys: toys),
      ]),
    );
  }
}
