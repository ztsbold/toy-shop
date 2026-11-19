import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/shop_repository.dart';
import '../../../../domain/models/toy.dart';
import '../../../core/format.dart';
import '../../../core/toy_image.dart';
import '../../cart/view_models/cart_view_model.dart';
import '../../cart/views/cart_screen.dart';
import '../view_models/catalog_view_model.dart';
import 'toy_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  late final CatalogViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = CatalogViewModel(repository: context.read<ShopRepository>())..load();
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartViewModel>().count;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тоглоомын дэлгүүр'),
        actions: [
          IconButton(
            tooltip: 'Сагс',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CartScreen())),
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          if (vm.loading && vm.toys.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Ачаалж байна...\nАнх нээхэд түр хугацаа шаардагдаж магадгүй.',
                      textAlign: TextAlign.center),
                ],
              ),
            );
          }
          if (vm.error != null && vm.toys.isEmpty) {
            return _ErrorView(message: vm.error!, onRetry: vm.load);
          }
          return RefreshIndicator(
            onRefresh: vm.load,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      onChanged: vm.search,
                      decoration: const InputDecoration(
                        hintText: 'Тоглоом хайх...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        _chip('Бүгд', vm.selectedCategory == null,
                            () => vm.selectCategory(null)),
                        for (final c in vm.categories)
                          _chip(c, vm.selectedCategory == c,
                              () => vm.selectCategory(c)),
                      ],
                    ),
                  ),
                ),
                if (vm.toys.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Тоглоом олдсонгүй')),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverGrid.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.66,
                      ),
                      itemCount: vm.toys.length,
                      itemBuilder: (_, i) => _ToyCard(toy: vm.toys[i]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
            label: Text(label), selected: selected, onSelected: (_) => onTap()),
      );
}

class _ToyCard extends StatelessWidget {
  const _ToyCard({required this.toy});
  final Toy toy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ToyDetailScreen(toy: toy))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: ToyImage(toy: toy)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(toy.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall),
                  const SizedBox(height: 2),
                  Text('${toy.ageRange} нас', style: text.bodySmall),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(formatMnt(toy.price),
                        style: text.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Сагсанд нэмэх',
                    onPressed: toy.inStock
                        ? () => addToCartWithFeedback(context, toy)
                        : null,
                    icon: const Icon(Icons.add_shopping_cart, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void addToCartWithFeedback(BuildContext context, Toy toy, {int qty = 1}) {
  final ok = context.read<CartViewModel>().add(toy, qty: qty);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(ok
          ? '${toy.name} сагсанд нэмэгдлээ'
          : 'Үлдэгдэл хүрэлцэхгүй байна (${toy.stock} ширхэг)'),
      duration: const Duration(seconds: 2),
    ));
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: onRetry, child: const Text('Дахин оролдох')),
            ],
          ),
        ),
      );
}
