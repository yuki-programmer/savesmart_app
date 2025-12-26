class Budget {
  int? id;
  int amount;
  int year;
  int month;

  Budget({
    this.id,
    required this.amount,
    required this.year,
    required this.month,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'year': year,
      'month': month,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] as int?,
      amount: map['amount'] as int,
      year: map['year'] as int,
      month: map['month'] as int,
    );
  }
}
