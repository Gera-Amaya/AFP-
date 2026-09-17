import 'category.dart';

class Transaction {
  final String id;
  final CategoryType type;
  final double amount;
  final String categoryId;
  final List<String> tags;
  final String description;
  final DateTime date;

  const Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    this.tags = const [],
    this.description = '',
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type.name,
    'amount': amount,
    'categoryId': categoryId,
    'tags': tags,
    'description': description,
    'date': date.millisecondsSinceEpoch,
  };

  factory Transaction.fromMap(Map<String, dynamic> map) => Transaction(
    id: map['id'] as String,
    type: CategoryType.values.firstWhere((e) => e.name == map['type']),
    amount: (map['amount'] as num).toDouble(),
    categoryId: map['categoryId'] as String,
    tags: (map['tags'] as List).cast<String>(),
    description: (map['description'] as String?) ?? '',
    date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
  );
}
