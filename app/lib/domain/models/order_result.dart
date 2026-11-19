class BankLink {
  const BankLink({
    required this.name,
    required this.description,
    required this.logo,
    required this.link,
  });

  final String name;
  final String description;
  final String logo;
  final String link;

  factory BankLink.fromJson(Map<String, dynamic> j) => BankLink(
        name: (j['name'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        logo: (j['logo'] ?? '') as String,
        link: (j['link'] ?? '') as String,
      );
}

/// Дансаар шилжүүлэх горимын мэдээлэл
class ManualTransfer {
  const ManualTransfer({
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    required this.reference,
    required this.note,
  });

  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final String reference; // гүйлгээний утга = захиалгын дугаар
  final String note;

  factory ManualTransfer.fromJson(Map<String, dynamic> j) => ManualTransfer(
        bankName: (j['bankName'] ?? '') as String,
        accountNumber: (j['accountNumber'] ?? '') as String,
        accountHolder: (j['accountHolder'] ?? '') as String,
        reference: (j['reference'] ?? '') as String,
        note: (j['note'] ?? '') as String,
      );
}

class PaymentInvoice {
  const PaymentInvoice({
    required this.invoiceId,
    required this.qrImage,
    required this.qrText,
    required this.shortUrl,
    required this.banks,
    this.manual,
  });

  final String invoiceId;
  final String qrImage; // base64 PNG
  final String qrText;
  final String shortUrl;
  final List<BankLink> banks;
  final ManualTransfer? manual;

  factory PaymentInvoice.fromJson(Map<String, dynamic> j) => PaymentInvoice(
        invoiceId: j['invoiceId'] as String,
        qrImage: (j['qrImage'] ?? '') as String,
        qrText: (j['qrText'] ?? '') as String,
        shortUrl: (j['shortUrl'] ?? '') as String,
        banks: ((j['banks'] ?? []) as List)
            .cast<Map<String, dynamic>>()
            .map(BankLink.fromJson)
            .toList(),
        manual: j['manual'] is Map<String, dynamic>
            ? ManualTransfer.fromJson(j['manual'] as Map<String, dynamic>)
            : null,
      );
}

class OrderResult {
  const OrderResult({
    required this.orderId,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.invoice,
    this.paymentMode = 'qpay',
  });

  final String orderId;
  final int subtotal;
  final int deliveryFee;
  final int total;
  final PaymentInvoice invoice;
  final String paymentMode; // qpay | manual | mock

  bool get isManual => paymentMode == 'manual';

  factory OrderResult.fromJson(Map<String, dynamic> j) => OrderResult(
        orderId: j['orderId'] as String,
        subtotal: (j['subtotal'] as num).toInt(),
        deliveryFee: (j['deliveryFee'] as num).toInt(),
        total: (j['total'] as num).toInt(),
        invoice:
            PaymentInvoice.fromJson(j['invoice'] as Map<String, dynamic>),
        paymentMode: (j['paymentMode'] ?? 'qpay') as String,
      );
}
