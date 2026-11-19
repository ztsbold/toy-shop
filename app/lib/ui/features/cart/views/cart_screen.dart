import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../core/toy_image.dart';
import '../../../core/widgets.dart';
import '../../checkout/views/checkout_screen.dart';
import '../view_models/cart_view_model.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Сагс')),
      body: cart.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              message: 'Сагс хоосон байна',
              actionLabel: 'Тоглоом үзэх',
              onAction: () => Navigator.maybePop(context),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cart.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final item = cart.items[i];
                final t = item.toy;
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Container(
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.sky,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ToyImage(toy: t, emojiSize: 34),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                          if (t.subtitle.isNotEmpty)
                            Text(t.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5, color: AppColors.muted)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Expanded(
                              child: Text(formatMnt(item.subtotal),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.blue)),
                            ),
                            QuantityStepper(
                              compact: true,
                              value: item.qty,
                              min: 0,
                              max: t.stock,
                              onChanged: (v) => cart.setQty(t.id, v),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ]),
                );
              },
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      const Expanded(
                        child: Text('Барааны дүн',
                            style: TextStyle(fontSize: 16)),
                      ),
                      Text(formatMnt(cart.subtotal),
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.blue)),
                    ]),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Хүргэлтийн төрлийг дараагийн алхамд сонгоно.',
                          style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CheckoutScreen())),
                        child: const Text('Захиалга өгөх'),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
    );
  }
}
