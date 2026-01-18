/// 数値を3桁区切りでフォーマットする
/// 例: 1234567 → "1,234,567"
String formatNumber(int number) {
  return number.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}

/// 通貨形式で金額をフォーマットする
/// [format]: 'prefix' → ¥1,234 / 'suffix' → 1,234円
/// 例: formatCurrency(1234, 'prefix') → "¥1,234"
/// 例: formatCurrency(1234, 'suffix') → "1,234円"
String formatCurrency(int amount, String format) {
  final formatted = formatNumber(amount);
  if (format == 'suffix') {
    return '$formatted円';
  }
  return '¥$formatted';
}
