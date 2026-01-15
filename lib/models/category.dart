class Category {
  int? id;
  String name;
  int sortOrder;
  bool isDefault;
  String? icon; // Material Iconの名前（例: 'restaurant', 'train'）

  Category({
    this.id,
    required this.name,
    required this.sortOrder,
    this.isDefault = false,
    this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'sort_order': sortOrder,
      'is_default': isDefault ? 1 : 0,
      'icon': icon,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      sortOrder: map['sort_order'] as int,
      isDefault: (map['is_default'] as int) == 1,
      icon: map['icon'] as String?,
    );
  }
}
