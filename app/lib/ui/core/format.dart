/// 125000 -> "125,000"
String formatNumber(int value) => formatMnt(value).replaceAll('₮', '');

/// 125000 -> "125,000₮"
String formatMnt(int value) {
  final s = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${value < 0 ? '-' : ''}${buf.toString()}₮';
}
