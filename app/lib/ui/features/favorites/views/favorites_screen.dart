import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets.dart';
import '../../catalog/view_models/catalog_view_model.dart';
import '../../shell/home_shell.dart';
import '../view_models/favorites_view_model.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ids = context.watch<FavoritesViewModel>().ids;
    final toys = context.watch<CatalogViewModel>().byIds(ids);

    return Scaffold(
      appBar: AppBar(title: const Text('Хүслүүд'), actions: const [CartButton()]),
      body: toys.isEmpty
          ? EmptyState(
              icon: Icons.favorite_border,
              message: 'Таалагдсан тоглоомынхоо зүрхэн дээр дарж энд хадгална уу.',
              actionLabel: 'Тоглоом үзэх',
              onAction: () => HomeShell.of(context)?.selectTab(0),
            )
          : CustomScrollView(slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ProductGrid(toys: toys),
            ]),
    );
  }
}
