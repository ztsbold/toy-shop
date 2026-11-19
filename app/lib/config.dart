/// Backend хаяг. Ажиллуулахдаа:
///   flutter run --dart-define=API_URL=https://api.taniidelguur.mn
/// Android эмулятор дээр компьютерийн localhost нь 10.0.2.2 байна.
const String apiBaseUrl =
    String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');

/// Апп дээр урьдчилан харуулах хүргэлтийн үнэ (эцсийн дүнг сервер тооцно).
const int deliveryFee = 50;
const int freeDeliveryFrom = 100000;

const List<String> districts = [
  'Баянгол',
  'Баянзүрх',
  'Сонгинохайрхан',
  'Сүхбаатар',
  'Хан-Уул',
  'Чингэлтэй',
  'Налайх',
  'Багануур',
  'Багахангай',
  'Орон нутаг',
];
