class Expense {
  int? id;
  int amount;
  int categoryId;
  String category; // カテゴリ名（JOINで取得、表示用）
  String grade;
  String? memo;
  DateTime createdAt;
  int? parentId;

  Expense({
    this.id,
    required this.amount,
    required this.categoryId,
    required this.category,
    required this.grade,
    this.memo,
    required this.createdAt,
    this.parentId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category_id': categoryId,
      'grade': grade,
      'memo': memo,
      'created_at': createdAt.toIso8601String(),
      'parent_id': parentId,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      amount: map['amount'] as int,
      categoryId: map['category_id'] as int,
      category: map['category_name'] as String? ?? map['category'] as String? ?? '',
      grade: map['grade'] as String,
      memo: map['memo'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      parentId: map['parent_id'] as int?,
    );
  }

  Expense copyWith({
    int? id,
    int? amount,
    int? categoryId,
    String? category,
    String? grade,
    String? memo,
    DateTime? createdAt,
    int? parentId,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      grade: grade ?? this.grade,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
      parentId: parentId ?? this.parentId,
    );
  }
}
