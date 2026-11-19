class DeliveryOption {
  const DeliveryOption({
    required this.id,
    required this.name,
    required this.eta,
    required this.fee,
  });

  final String id;
  final String name;
  final String eta;
  final int fee;

  factory DeliveryOption.fromJson(Map<String, dynamic> j) => DeliveryOption(
        id: (j['id'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        eta: (j['eta'] ?? '') as String,
        fee: (j['fee'] as num? ?? 0).toInt(),
      );
}

class LoyaltyConfig {
  const LoyaltyConfig({
    this.pointsPerAmount = 1000,
    this.pointValue = 1,
    this.maxPercent = 100,
  });

  final int pointsPerAmount; // хэдэн ₮ тутамд 1 оноо
  final int pointValue; // 1 оноо = хэдэн ₮
  final int maxPercent; // оноогоор төлж болох барааны дүнгийн дээд хувь

  /// Төлсөн мөнгөнөөс олгогдох оноо
  int pointsFor(int paidGoodsAmount) =>
      paidGoodsAmount <= 0 ? 0 : paidGoodsAmount ~/ pointsPerAmount;

  /// Энэ захиалгад ашиглаж болох дээд оноо
  int maxUsable({required int balance, required int eligibleSubtotal}) {
    final cap = (eligibleSubtotal * maxPercent) ~/ 100 ~/ pointValue;
    return balance < cap ? balance : cap;
  }

  factory LoyaltyConfig.fromJson(Map<String, dynamic> j) => LoyaltyConfig(
        pointsPerAmount: ((j['pointsPerAmount'] as num?) ?? 1000).toInt().clamp(1, 1 << 30),
        pointValue: ((j['pointValue'] as num?) ?? 1).toInt().clamp(1, 1 << 30),
        maxPercent: ((j['maxPercent'] as num?) ?? 100).toInt().clamp(0, 100),
      );
}

class ShopConfig {
  const ShopConfig({
    required this.deliveryOptions,
    this.freeDeliveryFrom = 0,
    this.shopPhone = '',
    this.shopAddress = '',
    this.workHours = '',
    this.loyalty = const LoyaltyConfig(),
  });

  final List<DeliveryOption> deliveryOptions;
  final int freeDeliveryFrom; // зөвхөн стандарт хүргэлтэд
  final String shopPhone;
  final String shopAddress;
  final String workHours;
  final LoyaltyConfig loyalty;

  /// Сервертэй ижил дүрмээр тооцно (эцсийн дүнг сервер тооцно).
  int feeFor(DeliveryOption option, int subtotal) {
    if (option.id == 'standard' &&
        freeDeliveryFrom > 0 &&
        subtotal >= freeDeliveryFrom) {
      return 0;
    }
    return option.fee;
  }

  static const fallback = ShopConfig(deliveryOptions: [
    DeliveryOption(
        id: 'standard', name: 'Стандарт хүргэлт', eta: '1-2 өдөр', fee: 5000),
  ]);

  factory ShopConfig.fromJson(Map<String, dynamic> j) {
    final options = ((j['deliveryOptions'] ?? const []) as List)
        .whereType<Map<String, dynamic>>()
        .map(DeliveryOption.fromJson)
        .toList();
    return ShopConfig(
      deliveryOptions:
          options.isEmpty ? fallback.deliveryOptions : options,
      freeDeliveryFrom: (j['freeDeliveryFrom'] as num? ?? 0).toInt(),
      shopPhone: (j['shopPhone'] ?? '') as String,
      shopAddress: (j['shopAddress'] ?? '') as String,
      workHours: (j['workHours'] ?? '') as String,
      loyalty: j['loyalty'] is Map<String, dynamic>
          ? LoyaltyConfig.fromJson(j['loyalty'] as Map<String, dynamic>)
          : const LoyaltyConfig(),
    );
  }
}
