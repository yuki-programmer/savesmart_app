class FixedCost {
  int? id;
  int? categoryId; // 固定費カテゴリID（nullは「その他」扱い）
  String? categoryNameSnapshot; // 保存時のカテゴリ名スナップショット
  int amount;
  String? memo;
  DateTime createdAt;

  // 後方互換性のため、nameは categoryNameSnapshot のエイリアスとして機能
  String get name => categoryNameSnapshot ?? 'その他（固定費）';

  FixedCost({
    this.id,
    this.categoryId,
    this.categoryNameSnapshot,
    required this.amount,
    this.memo,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'category_name_snapshot': categoryNameSnapshot,
      'amount': amount,
      'memo': memo,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FixedCost.fromMap(Map<String, dynamic> map) {
    // 後方互換性: 古いデータには name があり、category_id がない
    final legacyName = map['name'] as String?;
    final categoryNameSnapshot = map['category_name_snapshot'] as String? ?? legacyName;

    return FixedCost(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int?,
      categoryNameSnapshot: categoryNameSnapshot,
      amount: map['amount'] as int,
      memo: map['memo'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  FixedCost copyWith({
    int? id,
    int? categoryId,
    String? categoryNameSnapshot,
    int? amount,
    String? memo,
    DateTime? createdAt,
  }) {
    return FixedCost(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryNameSnapshot: categoryNameSnapshot ?? this.categoryNameSnapshot,
      amount: amount ?? this.amount,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
