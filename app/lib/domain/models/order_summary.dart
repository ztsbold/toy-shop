class OrderEvent {
  const OrderEvent({required this.status, required this.at});
  final String status;
  final DateTime at;

  factory OrderEvent.fromJson(Map<String, dynamic> j) => OrderEvent(
        status: (j['status'] ?? '') as String,
        at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num? ?? 0).toInt()),
      );
}

class OrderLine {
  const OrderLine({required this.name, required this.qty, required this.price});
  final String name;
  final int qty;
  final int price;

  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(
        name: (j['name'] ?? '') as String,
        qty: (j['qty'] as num? ?? 0).toInt(),
        price: (j['price'] as num? ?? 0).toInt(),
      );
}

class OrderSummary {
  const OrderSummary({
    required this.orderId,
    required this.status,
    required this.fulfillment,
    required this.total,
    required this.createdAt,
    required this.itemCount,
    required this.firstItem,
    required this.deliveryOption,
    this.subtotal = 0,
    this.deliveryFee = 0,
    this.pointsUsed = 0,
    this.pointsEarned = 0,
    this.items = const [],
    this.history = const [],
  });

  final String orderId;
  final String status; // PENDING | PAID
  final String fulfillment; // NEW | PREPARING | SHIPPING | DELIVERED | CANCELLED
  final int total;
  final DateTime createdAt;
  final int itemCount;
  final String firstItem;
  final String deliveryOption;
  final int subtotal;
  final int deliveryFee;
  final int pointsUsed;
  final int pointsEarned;
  final List<OrderLine> items;
  final List<OrderEvent> history;

  bool get isPaid => status == 'PAID';
  bool get isCancelled => fulfillment == 'CANCELLED';

  String get statusLabel {
    if (isCancelled) return 'Цуцлагдсан';
    if (!isPaid) return 'Төлбөр хүлээж буй';
    return switch (fulfillment) {
      'PREPARING' => 'Бэлтгэж байна',
      'SHIPPING' => 'Хүргэлтэнд гарсан',
      'DELIVERED' => 'Хүргэгдсэн',
      _ => 'Төлөгдсөн',
    };
  }

  /// Тухайн алхам болсон цаг (болоогүй бол null)
  DateTime? timeOf(String status) {
    for (final e in history.reversed) {
      if (e.status == status) return e.at;
    }
    return null;
  }

  factory OrderSummary.fromJson(Map<String, dynamic> j) => OrderSummary(
        orderId: j['orderId'] as String,
        status: (j['status'] ?? 'PENDING') as String,
        fulfillment: (j['fulfillment'] ?? 'NEW') as String,
        total: (j['total'] as num? ?? 0).toInt(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (j['createdAt'] as num? ?? 0).toInt()),
        itemCount: (j['itemCount'] as num? ?? 0).toInt(),
        firstItem: (j['firstItem'] ?? '') as String,
        deliveryOption: (j['deliveryOption'] ?? '') as String,
        subtotal: (j['subtotal'] as num? ?? 0).toInt(),
        deliveryFee: (j['deliveryFee'] as num? ?? 0).toInt(),
        pointsUsed: (j['pointsUsed'] as num? ?? 0).toInt(),
        pointsEarned: (j['pointsEarned'] as num? ?? 0).toInt(),
        items: ((j['items'] ?? const []) as List)
            .whereType<Map<String, dynamic>>()
            .map(OrderLine.fromJson)
            .toList(),
        history: ((j['history'] ?? const []) as List)
            .whereType<Map<String, dynamic>>()
            .map(OrderEvent.fromJson)
            .toList(),
      );
}
