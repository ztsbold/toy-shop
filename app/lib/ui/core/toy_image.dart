import 'package:flutter/material.dart';

import '../../domain/models/toy.dart';

/// Зураг байвал зургийг, үгүй бол emoji-г харуулна. Дэвсгэргүй (тунгалаг).
class ToyImage extends StatelessWidget {
  const ToyImage({super.key, required this.toy, this.emojiSize = 56});

  final Toy toy;
  final double emojiSize;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(toy.emoji, style: TextStyle(fontSize: emojiSize)),
    );
    if (toy.imageUrl.isEmpty) return fallback;
    return Image.network(
      toy.imageUrl,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => fallback,
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : const Center(
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2))),
    );
  }
}
