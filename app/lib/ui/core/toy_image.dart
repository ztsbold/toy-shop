import 'package:flutter/material.dart';

import '../../domain/models/toy.dart';

/// Зураг байвал зургийг, үгүй бол emoji-г харуулна.
class ToyImage extends StatelessWidget {
  const ToyImage({super.key, required this.toy, this.emojiSize = 56});

  final Toy toy;
  final double emojiSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Center(
      child: Text(toy.emoji, style: TextStyle(fontSize: emojiSize)),
    );
    return Container(
      color: scheme.primaryContainer.withValues(alpha: 0.5),
      child: toy.imageUrl.isEmpty
          ? fallback
          : Image.network(
              toy.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}
