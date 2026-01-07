class FixedCostCategory {
  int? id;
  String name;
  bool isDefault;
  int sortOrder;

  FixedCostCategory({
    this.id,
    required this.name,
    this.isDefault = false,
    required this.sortOrder,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_default': isDefault ? 1 : 0,
      'sort_order': sortOrder,
    };
  }

  factory FixedCostCategory.fromMap(Map<String, dynamic> map) {
    return FixedCostCategory(
      id: map['id'] as int?,
      name: map['name'] as String,
      isDefault: (map['is_default'] as int?) == 1,
      sortOrder: map['sort_order'] as int,
    );
  }

  FixedCostCategory copyWith({
    int? id,
    String? name,
    bool? isDefault,
    int? sortOrder,
  }) {
    return FixedCostCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
