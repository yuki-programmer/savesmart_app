class AppConstants {
  static const String appName = 'SaveSmart';

  static const List<String> defaultCategories = [
    'コーヒー',
    'ランチ',
    '食料品',
    '交通費',
    '買い物',
    '娯楽',
    '医療',
    'その他',
  ];

  static const List<String> types = [
    'saving',
    'standard',
    'reward',
  ];

  static const Map<String, String> typeLabels = {
    'saving': '💰 節約',
    'standard': '🎯 標準',
    'reward': '⭐ ご褒美',
  };
}
