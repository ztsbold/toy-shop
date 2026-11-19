class ToyFeature {
  const ToyFeature({required this.value, required this.label});
  final String value;
  final String label;

  factory ToyFeature.fromJson(Map<String, dynamic> j) => ToyFeature(
        value: (j['value'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
      );
}

class Toy {
  const Toy({
    required this.id,
    required this.name,
    this.subtitle = '',
    this.sku = '',
    required this.category,
    required this.ageRange,
    required this.price,
    required this.stock,
    required this.emoji,
    required this.imageUrl,
    required this.description,
    this.isNew = false,
    this.pointsEligible = false,
    this.features = const [],
  });

  final String id;
  final String name;
  final String subtitle;
  final String sku;
  final String category;
  final String ageRange;
  final int price;
  final int stock;
  final String emoji;
  final String imageUrl; // бүтэн хаяг болгож хувиргасан
  final String description;
  final bool isNew;
  final bool pointsEligible; // оноогоор авч болох
  final List<ToyFeature> features;

  bool get inStock => stock > 0;

  /// [baseUrl] — "/images/..." мэт харьцангуй хаягийг бүтэн болгоход.
  factory Toy.fromJson(Map<String, dynamic> json, {String baseUrl = ''}) {
    final rawImage = (json['imageUrl'] ?? '') as String;
    return Toy(
      id: json['id'] as String,
      name: json['name'] as String,
      subtitle: (json['subtitle'] ?? '') as String,
      sku: (json['sku'] ?? '') as String,
      category: (json['category'] ?? '') as String,
      ageRange: (json['ageRange'] ?? '') as String,
      price: (json['price'] as num).toInt(),
      stock: (json['stock'] as num? ?? 0).toInt(),
      emoji: (json['emoji'] ?? '🎁') as String,
      imageUrl: rawImage.startsWith('/') ? '$baseUrl$rawImage' : rawImage,
      description: (json['description'] ?? '') as String,
      isNew: json['isNew'] == true,
      pointsEligible: json['pointsEligible'] == true,
      features: ((json['features'] ?? const []) as List)
          .whereType<Map<String, dynamic>>()
          .map(ToyFeature.fromJson)
          .toList(),
    );
  }
}
