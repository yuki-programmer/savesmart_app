class ScheduledExpense {
  int? id;
  int amount;
  int categoryId;
  String category; // カテゴリ名（JOINで取得、表示用）
  String grade;
  String? memo;
  DateTime scheduledDate;
  bool confirmed;
  DateTime? confirmedAt;
  DateTime createdAt;

  ScheduledExpense({
    this.id,
    required this.amount,
    required this.categoryId,
    required this.category,
    required this.grade,
    this.memo,
    required this.scheduledDate,
    this.confirmed = false,
    this.confirmedAt,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category_id': categoryId,
      'grade': grade,
      'memo': memo,
      'scheduled_date': scheduledDate.toIso8601String(),
      'confirmed': confirmed ? 1 : 0,
      'confirmed_at': confirmedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ScheduledExpense.fromMap(Map<String, dynamic> map) {
    return ScheduledExpense(
      id: map['id'] as int?,
      amount: map['amount'] as int,
      categoryId: map['category_id'] as int,
      category: map['category_name'] as String? ?? map['category'] as String? ?? '',
      grade: map['grade'] as String,
      memo: map['memo'] as String?,
      scheduledDate: DateTime.parse(map['scheduled_date'] as String),
      confirmed: (map['confirmed'] as int) == 1,
      confirmedAt: map['confirmed_at'] != null
          ? DateTime.parse(map['confirmed_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  ScheduledExpense copyWith({
    int? id,
    int? amount,
    int? categoryId,
    String? category,
    String? grade,
    String? memo,
    DateTime? scheduledDate,
    bool? confirmed,
    DateTime? confirmedAt,
    DateTime? createdAt,
  }) {
    return ScheduledExpense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
      grade: grade ?? this.grade,
      memo: memo ?? this.memo,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      confirmed: confirmed ?? this.confirmed,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
