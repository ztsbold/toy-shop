class Toy {
  const Toy({
    required this.id,
    required this.name,
    required this.category,
    required this.ageRange,
    required this.price,
    required this.stock,
    required this.emoji,
    required this.imageUrl,
    required this.description,
  });

  final String id;
  final String name;
  final String category;
  final String ageRange;
  final int price;
  final int stock;
  final String emoji;
  final String imageUrl;
  final String description;

  bool get inStock => stock > 0;

  factory Toy.fromJson(Map<String, dynamic> json) => Toy(
        id: json['id'] as String,
        name: json['name'] as String,
        category: (json['category'] ?? '') as String,
        ageRange: (json['ageRange'] ?? '') as String,
        price: (json['price'] as num).toInt(),
        stock: (json['stock'] as num? ?? 0).toInt(),
        emoji: (json['emoji'] ?? '🎁') as String,
        imageUrl: (json['imageUrl'] ?? '') as String,
        description: (json['description'] ?? '') as String,
      );
}
