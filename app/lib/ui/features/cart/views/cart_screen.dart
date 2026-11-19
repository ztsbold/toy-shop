import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../config.dart' as config;
import '../../../core/format.dart';
import '../../../core/toy_image.dart';
import '../../checkout/views/checkout_screen.dart';
import '../view_models/cart_view_model.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartViewModel>();
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Сагс')),
      body: cart.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🛒', style: TextStyle(fontSize: 64)),
                  SizedBox(height: 8),
                  Text('Сагс хоосон байна'),
                ],
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = cart.items[i];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child:
                                      ToyImage(toy: item.toy, emojiSize: 32)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.toy.name,
                                      style: text.titleSmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  Text(formatMnt(item.subtotal),
                                      style: text.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  cart.setQty(item.toy.id, item.qty - 1),
                              icon: Icon(item.qty == 1
                                  ? Icons.delete_outline
                                  : Icons.remove),
                            ),
                            Text('${item.qty}', style: text.titleMedium),
                            IconButton(
                              onPressed: item.qty < item.toy.stock
                                  ? () =>
                                      cart.setQty(item.toy.id, item.qty + 1)
                                  : null,
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
      bottomNavigationBar: cart.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _row('Барааны дүн', formatMnt(cart.subtotal)),
                    _row(
                        'Хүргэлт',
                        cart.deliveryFee == 0
                            ? 'Үнэгүй'
                            : formatMnt(cart.deliveryFee)),
                    if (cart.deliveryFee > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${formatMnt(config.freeDeliveryFrom)}-с дээш захиалгад хүргэлт үнэгүй',
                          style: text.bodySmall,
                        ),
                      ),
                    const Divider(),
                    _row('Нийт', formatMnt(cart.total), bold: true),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CheckoutScreen())),
                      child: const Text('Захиалга өгөх'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = TextStyle(
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: bold ? 18 : 15);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
