import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config.dart';
import '../../../../domain/models/toy.dart';
import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../core/toy_image.dart';
import '../../../core/widgets.dart';
import '../../config/shop_config_view_model.dart';
import '../../favorites/view_models/favorites_view_model.dart';

class ToyDetailScreen extends StatefulWidget {
  const ToyDetailScreen({super.key, required this.toy});
  final Toy toy;

  @override
  State<ToyDetailScreen> createState() => _ToyDetailScreenState();
}

class _ToyDetailScreenState extends State<ToyDetailScreen> {
  int qty = 1;

  Future<void> _ask() async {
    final phone = context.read<ShopConfigViewModel>().config.shopPhone;
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Дэлгүүрийн утасны дугаар тохируулаагүй байна.')));
      return;
    }
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  void _share() {
    final t = widget.toy;
    SharePlus.instance.share(ShareParams(
      subject: t.name,
      text: '${t.name}${t.subtitle.isNotEmpty ? ' (${t.subtitle})' : ''}\n'
          '${formatMnt(t.price)}\n$brandMark $brandName',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final toy = widget.toy;
    final fav = context.watch<FavoritesViewModel>().contains(toy.id);
    final features = toy.features.take(3).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // Дээд мөр
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(children: [
                    IconButton(
                      tooltip: 'Буцах',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.blue, size: 28),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Хуваалцах',
                      onPressed: _share,
                      icon: const Icon(Icons.ios_share,
                          color: AppColors.blue, size: 26),
                    ),
                    IconButton(
                      tooltip: fav ? 'Хүслээс хасах' : 'Хүсэлд нэмэх',
                      onPressed: () =>
                          context.read<FavoritesViewModel>().toggle(toy.id),
                      icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                          color: AppColors.blue, size: 28),
                    ),
                  ]),
                ),
                // Зураг
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: AspectRatio(
                    aspectRatio: 1.15,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.sky,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Stack(children: [
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: ToyImage(toy: toy, emojiSize: 120),
                          ),
                        ),
                        if (toy.ageRange.isNotEmpty)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: _AgeBadge(age: toy.ageRange),
                          ),
                      ]),
                    ),
                  ),
                ),
                // Нэр, код
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(toy.name,
                          style: const TextStyle(
                              fontSize: 26,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: AppColors.blueDeep)),
                      if (toy.subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(toy.subtitle,
                              style: const TextStyle(
                                  fontSize: 15, color: AppColors.muted)),
                        ),
                      const SizedBox(height: 10),
                      Row(children: [
                        if (toy.category.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.sky,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(toy.category.toUpperCase(),
                                style: const TextStyle(
                                    color: AppColors.blueDeep,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13)),
                          ),
                        if (toy.category.isNotEmpty && toy.sku.isNotEmpty)
                          Container(
                              width: 28,
                              height: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 10),
                              color: AppColors.line),
                        if (toy.sku.isNotEmpty)
                          Text(toy.sku,
                              style: const TextStyle(
                                  fontSize: 15, color: AppColors.muted)),
                      ]),
                      const SizedBox(height: 14),
                      // Үнэ ба тоо
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text.rich(TextSpan(children: [
                              TextSpan(
                                  text: formatMnt(toy.price),
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.blueDeep)),
                              const TextSpan(
                                  text: '  / ширхэг',
                                  style: TextStyle(
                                      fontSize: 15, color: AppColors.muted)),
                            ])),
                          ),
                          if (toy.inStock)
                            QuantityStepper(
                              value: qty,
                              max: toy.stock,
                              onChanged: (v) => setState(() => qty = v),
                            ),
                        ],
                      ),
                      if (toy.pointsEligible)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF6D6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.stars_rounded, color: Color(0xFFB7791F), size: 20),
                              SizedBox(width: 6),
                              Text('Оноогоор авч болно',
                                  style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF8A5A00))),
                            ]),
                          ),
                        ),
                      if (!toy.inStock)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('Түр дууссан',
                              style: TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w700)),
                        )
                      else if (toy.stock <= 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('Үлдсэн ${toy.stock} ширхэг',
                              style: const TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600)),
                        ),
                      // Тайлбар
                      if (toy.description.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const Row(children: [
                          Icon(Icons.description_outlined,
                              color: AppColors.blue, size: 26),
                          SizedBox(width: 8),
                          Text('Тайлбар',
                              style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.blueDeep)),
                        ]),
                        const SizedBox(height: 8),
                        Text(toy.description,
                            style: const TextStyle(
                                fontSize: 15.5,
                                height: 1.55,
                                color: AppColors.ink)),
                      ],
                      if (features.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _FeatureRow(features: features),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(children: [
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: _ask,
                  icon: const Icon(Icons.headset_mic_outlined),
                  label: const Text('Асуух'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.sun,
                    foregroundColor: AppColors.blueDeep,
                    disabledBackgroundColor: AppColors.line,
                  ),
                  onPressed: toy.inStock
                      ? () => addToCartWithFeedback(context, toy, qty: qty)
                      : null,
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: Text(toy.inStock ? 'Сагсанд нэмэх' : 'Дууссан'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _AgeBadge extends StatelessWidget {
  const _AgeBadge({required this.age});
  final String age;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.verified_user, color: AppColors.blue, size: 26),
            const SizedBox(width: 4),
            Text(age,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.blueDeep)),
          ]),
          const Text('НАСТАЙ',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.blueDeep)),
        ]),
      );
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.features});
  final List<ToyFeature> features;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < features.length; i++) {
      final f = features[i];
      if (i > 0) {
        children.add(Container(
            width: 1,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.line));
      }
      children.add(Expanded(
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(iconForFeature(f.label), color: AppColors.blue, size: 34),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (f.value.isNotEmpty)
                  Text(f.value,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.blueDeep)),
                Text(f.label.toUpperCase(),
                    maxLines: 2,
                    style: TextStyle(
                        fontSize: 12.5,
                        height: 1.2,
                        fontWeight:
                            f.value.isEmpty ? FontWeight.w700 : FontWeight.w500,
                        color: AppColors.ink)),
              ],
            ),
          ),
        ]),
      ));
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.line),
          bottom: BorderSide(color: AppColors.line),
        ),
      ),
      child: Row(children: children),
    );
  }
}
