class Category {
  int? id;
  String name;
  int sortOrder;
  bool isDefault;

  Category({
    this.id,
    required this.name,
    required this.sortOrder,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int,
      isDefault: (map['is_default'] as int) == 1,
    );
  }
}
