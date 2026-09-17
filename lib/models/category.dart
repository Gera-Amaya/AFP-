enum CategoryType { income, expense }

class Category {
  final String id;
  final String name;
  final CategoryType type;
  final String icon;
  final int colorValue;

  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.colorValue,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type.name,
    'icon': icon,
    'colorValue': colorValue,
  };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
    id: map['id'] as String,
    name: map['name'] as String,
    type: CategoryType.values.firstWhere((e) => e.name == map['type']),
    icon: map['icon'] as String,
    colorValue: map['colorValue'] as int,
  );
}
