/// 数値を3桁区切りでフォーマットする
/// 例: 1234567 → "1,234,567"
String formatNumber(int number) {
  return number.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}
