class CategoryBudget {
  int? id;
  int categoryId;
  String categoryName; // カテゴリ名（JOINで取得、表示用）
  int budgetAmount;
  String periodType; // 'recurring' or 'one_time'
  DateTime createdAt;

  CategoryBudget({
    this.id,
    required this.categoryId,
    required this.categoryName,
    required this.budgetAmount,
    required this.periodType,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'budget_amount': budgetAmount,
      'period_type': periodType,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CategoryBudget.fromMap(Map<String, dynamic> map) {
    return CategoryBudget(
      id: map['id'] as int?,
      categoryId: map['category_id'] as int,
      categoryName: map['category_name'] as String? ?? '',
      budgetAmount: map['budget_amount'] as int,
      periodType: map['period_type'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  CategoryBudget copyWith({
    int? id,
    int? categoryId,
    String? categoryName,
    int? budgetAmount,
    String? periodType,
    DateTime? createdAt,
  }) {
    return CategoryBudget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      periodType: periodType ?? this.periodType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 毎月継続かどうか
  bool get isRecurring => periodType == 'recurring';

  /// 今月のみかどうか
  bool get isOneTime => periodType == 'one_time';
}
