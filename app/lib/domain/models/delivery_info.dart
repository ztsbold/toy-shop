enum ReceiptType { personal, company }

class DeliveryInfo {
  const DeliveryInfo({
    required this.fullName,
    required this.phone,
    required this.district,
    this.khoroo = '',
    this.building = '',
    this.apartment = '',
    this.note = '',
    this.receiptType = ReceiptType.personal,
    this.companyRegister = '',
  });

  final String fullName;
  final String phone;
  final String district;
  final String khoroo;
  final String building; // байр
  final String apartment; // орц, давхар, тоот
  final String note;
  final ReceiptType receiptType; // И-баримт
  final String companyRegister;

  /// Сервер рүү илгээх нэгтгэсэн хаяг
  String get address =>
      [building, apartment].where((s) => s.trim().isNotEmpty).join(', ');

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'phone': phone,
        'district': district,
        'khoroo': khoroo,
        'building': building,
        'apartment': apartment,
        'address': address,
        'note': note,
        'receiptType': receiptType.name,
        'companyRegister': companyRegister,
      };

  factory DeliveryInfo.fromJson(Map<String, dynamic> j) => DeliveryInfo(
        fullName: (j['fullName'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        district: (j['district'] ?? '') as String,
        khoroo: (j['khoroo'] ?? '') as String,
        building: (j['building'] ?? j['address'] ?? '') as String,
        apartment: (j['apartment'] ?? '') as String,
        note: (j['note'] ?? '') as String,
        receiptType: j['receiptType'] == 'company'
            ? ReceiptType.company
            : ReceiptType.personal,
        companyRegister: (j['companyRegister'] ?? '') as String,
      );
}
