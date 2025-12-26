class Expense {
  int? id;
  int amount;
  String category;
  String grade;
  String? memo;
  DateTime createdAt;
  int? parentId;

  Expense({
    this.id,
    required this.amount,
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
      'category': category,
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
      category: map['category'] as String,
      grade: map['grade'] as String,
      memo: map['memo'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      parentId: map['parent_id'] as int?,
    );
  }
}
