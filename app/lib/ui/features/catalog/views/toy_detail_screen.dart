import 'package:flutter/material.dart';

import '../../../../domain/models/toy.dart';
import '../../../core/format.dart';
import '../../../core/toy_image.dart';
import 'catalog_screen.dart' show addToCartWithFeedback;

class ToyDetailScreen extends StatefulWidget {
  const ToyDetailScreen({super.key, required this.toy});
  final Toy toy;

  @override
  State<ToyDetailScreen> createState() => _ToyDetailScreenState();
}

class _ToyDetailScreenState extends State<ToyDetailScreen> {
  int qty = 1;

  @override
  Widget build(BuildContext context) {
    final toy = widget.toy;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(toy.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                    aspectRatio: 1.3,
                    child: ToyImage(toy: toy, emojiSize: 120)),
              ),
              const SizedBox(height: 16),
              Text(toy.name, style: text.headlineSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                Chip(label: Text(toy.category)),
                Chip(label: Text('${toy.ageRange} нас')),
                Chip(
                    label: Text(toy.inStock
                        ? 'Үлдэгдэл: ${toy.stock}'
                        : 'Дууссан')),
              ]),
              const SizedBox(height: 8),
              Text(formatMnt(toy.price),
                  style: text.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(toy.description, style: text.bodyLarge),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton.outlined(
                onPressed: qty > 1 ? () => setState(() => qty--) : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$qty', style: text.titleLarge),
              ),
              IconButton.outlined(
                onPressed:
                    qty < toy.stock ? () => setState(() => qty++) : null,
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: toy.inStock
                      ? () => addToCartWithFeedback(context, toy, qty: qty)
                      : null,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Сагсанд нэмэх'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
