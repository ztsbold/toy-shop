import 'package:flutter/material.dart';

import '../../../../domain/models/order_result.dart';
import '../../../core/format.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key, required this.order});
  final OrderResult order;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 12),
                Text('Төлбөр амжилттай!', style: text.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Захиалга ${order.orderId}\n${formatMnt(order.total)} төлөгдлөө. '
                  'Бид удахгүй тантай холбогдож хүргэлтийг зохион байгуулна.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Дэлгүүр рүү буцах'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
