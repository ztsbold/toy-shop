enum ReceiptType { personal, company }

class DeliveryInfo {
  const DeliveryInfo({
    required this.fullName,
    required this.phone,
    this.extraPhone = '',
    required this.district,
    this.khoroo = '',
    required this.address,
    this.note = '',
    this.receiptType = ReceiptType.personal,
    this.companyRegister = '',
    this.email = '',
  });

  final String fullName;
  final String phone;
  final String extraPhone;
  final String district;
  final String khoroo;
  final String address; // байр, орц, давхар, тоот
  final String note; // хүргэлтийн тайлбар, цаг
  final ReceiptType receiptType; // И-баримт
  final String companyRegister;
  final String email;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'phone': phone,
        'extraPhone': extraPhone,
        'district': district,
        'khoroo': khoroo,
        'address': address,
        'note': note,
        'receiptType': receiptType.name,
        'companyRegister': companyRegister,
        'email': email,
      };

  factory DeliveryInfo.fromJson(Map<String, dynamic> j) => DeliveryInfo(
        fullName: (j['fullName'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        extraPhone: (j['extraPhone'] ?? '') as String,
        district: (j['district'] ?? '') as String,
        khoroo: (j['khoroo'] ?? '') as String,
        address: (j['address'] ?? '') as String,
        note: (j['note'] ?? '') as String,
        receiptType: j['receiptType'] == 'company'
            ? ReceiptType.company
            : ReceiptType.personal,
        companyRegister: (j['companyRegister'] ?? '') as String,
        email: (j['email'] ?? '') as String,
      );
}
