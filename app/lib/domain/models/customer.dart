class Customer {
  const Customer({
    required this.id,
    required this.phone,
    required this.name,
    required this.points,
    this.unread = 0,
  });

  final String id;
  final String phone;
  final String name;
  final int points;
  final int unread; // уншаагүй мессежийн тоо

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as String,
        phone: (j['phone'] ?? '') as String,
        name: (j['name'] ?? '') as String,
        points: (j['points'] as num? ?? 0).toInt(),
        unread: (j['unread'] as num? ?? 0).toInt(),
      );
}

class PointsEntry {
  const PointsEntry(
      {required this.delta, required this.reason, required this.createdAt});
  final int delta;
  final String reason;
  final DateTime createdAt;

  factory PointsEntry.fromJson(Map<String, dynamic> j) => PointsEntry(
        delta: (j['delta'] as num? ?? 0).toInt(),
        reason: (j['reason'] ?? '') as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (j['createdAt'] as num? ?? 0).toInt()),
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    this.orderId,
  });

  final String id;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
  final String? orderId;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['id'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        read: j['read'] == true,
        orderId: j['orderId'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (j['createdAt'] as num? ?? 0).toInt()),
      );
}

class AuthResult {
  const AuthResult(
      {required this.token, required this.customer, required this.isNew});
  final String token;
  final Customer customer;
  final bool isNew;
}
