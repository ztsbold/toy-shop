/// Backend хаяг. Build хийхдээ: --dart-define=API_URL=https://...
const String apiBaseUrl =
    String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:3000');

/// Брэнд (толгой хэсэгт харагдана)
const String brandMark = 'F5';
const String brandName = 'TOYS MONGOLIA';
const String brandTagline = 'Тоглоомын дэлгүүр';

/// Дүүрэг → хорооны тоо (2025 оны байдлаар)
const Map<String, int> districts = {
  'Баянгол': 34,
  'Баянзүрх': 43,
  'Сонгинохайрхан': 43,
  'Сүхбаатар': 22,
  'Хан-Уул': 25,
  'Чингэлтэй': 24,
  'Налайх': 8,
  'Багануур': 5,
  'Багахангай': 2,
  'Орон нутаг': 0,
};
