/// クイック登録エントリ
/// ホーム画面から1タップで支出を登録するためのプリセット
class QuickEntry {
  final int? id;
  final String title; // タイルに表示する名前
  final String category; // カテゴリ名
  final int amount; // 金額
  final String grade; // 'saving' | 'standard' | 'reward'
  final String? memo; // メモ（任意）
  final int sortOrder; // 表示順序

  QuickEntry({
    this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.grade,
    this.memo,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': amount,
      'grade': grade,
      'memo': memo,
      'sort_order': sortOrder,
    };
  }

  factory QuickEntry.fromMap(Map<String, dynamic> map) {
    return QuickEntry(
      id: map['id'] as int?,
      title: map['title'] as String,
      category: map['category'] as String,
      amount: map['amount'] as int,
      grade: map['grade'] as String,
      memo: map['memo'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  QuickEntry copyWith({
    int? id,
    String? title,
    String? category,
    int? amount,
    String? grade,
    String? memo,
    int? sortOrder,
  }) {
    return QuickEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      grade: grade ?? this.grade,
      memo: memo ?? this.memo,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
