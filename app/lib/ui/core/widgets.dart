import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config.dart';
import '../../domain/models/toy.dart';
import '../features/cart/view_models/cart_view_model.dart';
import '../features/cart/views/cart_screen.dart';
import '../features/catalog/views/toy_detail_screen.dart';
import '../features/favorites/view_models/favorites_view_model.dart';
import 'format.dart';
import 'theme.dart';
import 'toy_image.dart';

/// "F5" лого + дэлгүүрийн нэр
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Transform(
          transform: Matrix4.skewX(-0.18),
          child: const Text(
            brandMark,
            style: TextStyle(
              fontSize: 36,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              color: AppColors.blue,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(brandName,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            SizedBox(height: 2),
            Text(brandTagline,
                style: TextStyle(fontSize: 13, color: AppColors.ink)),
          ],
        ),
      ],
    );
  }
}

/// Сагсны товч, тоотой
class CartButton extends StatelessWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<CartViewModel>().count;
    return IconButton(
      tooltip: 'Сагс',
      onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const CartScreen())),
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: AppColors.blue,
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_outlined,
            size: 28, color: AppColors.ink),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(
      {super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(actionLabel!,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Icon(Icons.chevron_right, size: 20),
              ]),
            ),
        ],
      ),
    );
  }
}

/// − 1 + тоо сонгогч
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.compact = false,
  });

  final int value;
  final int min;
  final int max;
  final bool compact;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 44.0;
    Widget btn(IconData icon, VoidCallback? onTap, String tip) => SizedBox(
          width: size,
          height: size,
          child: IconButton(
            tooltip: tip,
            padding: EdgeInsets.zero,
            onPressed: onTap,
            icon: Icon(icon, size: compact ? 18 : 22),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.page,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        btn(Icons.remove, value > min ? () => onChanged(value - 1) : null,
            'Хасах'),
        SizedBox(
          width: compact ? 28 : 36,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: compact ? 15 : 18, fontWeight: FontWeight.w600)),
        ),
        btn(Icons.add, value < max ? () => onChanged(value + 1) : null,
            'Нэмэх'),
      ]),
    );
  }
}

IconData iconForCategory(String c) {
  final s = c.toLowerCase();
  if (s.contains('робот') || s.contains('robot')) return Icons.smart_toy_outlined;
  if (s.contains('үйлдл') || s.contains('консол') || s.contains('game')) {
    return Icons.sports_esports_outlined;
  }
  if (s.contains('лего') || s.contains('блок') || s.contains('барилг')) {
    return Icons.view_in_ar_outlined;
  }
  if (s.contains('машин') || s.contains('car')) {
    return Icons.directions_car_outlined;
  }
  if (s.contains('бүтээл') || s.contains('зураг') || s.contains('урлаг')) {
    return Icons.palette_outlined;
  }
  if (s.contains('зөөлөн') || s.contains('баавгай')) return Icons.pets_outlined;
  if (s.contains('спорт') || s.contains('бөмбөг')) {
    return Icons.sports_soccer_outlined;
  }
  if (s.contains('оюун') || s.contains('пазл')) return Icons.extension_outlined;
  if (s.contains('хүүхэлдэй')) return Icons.face_outlined;
  if (s.contains('үндэсний')) return Icons.castle_outlined;
  return Icons.toys_outlined;
}

IconData iconForFeature(String label) {
  final s = label.toLowerCase();
  if (s.contains('хэсэг') || s.contains('ширхэг')) {
    return Icons.view_in_ar_outlined;
  }
  if (s.contains('хэлбэр')) return Icons.smart_toy_outlined;
  if (s.contains('бат') || s.contains('аюулгүй') || s.contains('баталгаа')) {
    return Icons.verified_user_outlined;
  }
  if (s.contains('нас')) return Icons.child_care_outlined;
  if (s.contains('батерей') || s.contains('цэнэг')) {
    return Icons.battery_charging_full_outlined;
  }
  if (s.contains('хурд')) return Icons.speed_outlined;
  return Icons.star_outline;
}

/// Дугуй ангиллын товч
class CategoryBubble extends StatelessWidget {
  const CategoryBubble({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.blue : Colors.white,
                border: Border.all(
                    color: selected ? AppColors.blue : AppColors.line),
              ),
              child: Icon(iconForCategory(label),
                  size: 30, color: selected ? Colors.white : AppColors.ink),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.ink)),
          ]),
        ),
      ),
    );
  }
}

/// Сагсанд нэмээд мэдэгдэл харуулна
void addToCartWithFeedback(BuildContext context, Toy toy, {int qty = 1}) {
  final ok = context.read<CartViewModel>().add(toy, qty: qty);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(ok
          ? '${toy.name} сагсанд нэмэгдлээ'
          : 'Үлдэгдэл хүрэлцэхгүй байна (${toy.stock} ширхэг)'),
      duration: const Duration(seconds: 2),
      action: ok
          ? SnackBarAction(
              label: 'Сагс',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CartScreen())),
            )
          : null,
    ));
}

/// Барааны карт (нүүр, ангилал, хүслүүдийн жагсаалтад)
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.toy});
  final Toy toy;

  @override
  Widget build(BuildContext context) {
    final fav = context.watch<FavoritesViewModel>().contains(toy.id);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => ToyDetailScreen(toy: toy))),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 18, 8, 4),
                      child: ToyImage(toy: toy),
                    ),
                  ),
                  if (toy.isNew) const Positioned(left: 0, top: 0, child: NewBadge()),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: FavoriteButton(toyId: toy.id, active: fav, small: true),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
              Text(toy.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              if (toy.subtitle.isNotEmpty)
                Text(toy.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.ink)),
              const SizedBox(height: 2),
              Text(formatMnt(toy.price),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.blue)),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  onPressed: toy.inStock
                      ? () => addToCartWithFeedback(context, toy)
                      : null,
                  icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                  label: Text(toy.inStock ? 'Сагсанд нэмэх' : 'Дууссан'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NewBadge extends StatelessWidget {
  const NewBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.blue, borderRadius: BorderRadius.circular(6)),
        child: const Text('ШИНЭ',
            style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800)),
      );
}

class FavoriteButton extends StatelessWidget {
  const FavoriteButton(
      {super.key, required this.toyId, required this.active, this.small = false});

  final String toyId;
  final bool active;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(active ? Icons.favorite : Icons.favorite_border,
        color: active ? AppColors.blue : AppColors.ink,
        size: small ? 18 : 28);
    void onTap() => context.read<FavoritesViewModel>().toggle(toyId);
    if (!small) {
      return IconButton(
          tooltip: active ? 'Хүслээс хасах' : 'Хүсэлд нэмэх',
          onPressed: onTap,
          icon: icon);
    }
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: AppColors.line)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(6), child: icon),
      ),
    );
  }
}

/// Барааны торон жагсаалт (sliver)
class ProductGrid extends StatelessWidget {
  const ProductGrid({super.key, required this.toys});
  final List<Toy> toys;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisExtent: 290,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: toys.length,
        itemBuilder: (_, i) => ProductCard(toy: toys[i]),
      ),
    );
  }
}

/// Хоосон эсвэл алдааны төлөв
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.muted)),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ]),
        ),
      );
}
