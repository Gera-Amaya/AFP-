class PlannedExpense {
  final String id;
  final String name;
  final double amount;
  final String categoryId;
  final int dayOfMonth;
  final String? lastPaidKey;

  const PlannedExpense({
    required this.id,
    required this.name,
    required this.amount,
    required this.categoryId,
    required this.dayOfMonth,
    this.lastPaidKey,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'amount': amount,
    'categoryId': categoryId,
    'dayOfMonth': dayOfMonth,
    'lastPaidKey': lastPaidKey,
  };

  factory PlannedExpense.fromMap(Map<String, dynamic> map) => PlannedExpense(
    id: map['id'] as String,
    name: map['name'] as String,
    amount: (map['amount'] as num).toDouble(),
    categoryId: map['categoryId'] as String,
    dayOfMonth: map['dayOfMonth'] as int,
    lastPaidKey: map['lastPaidKey'] as String?,
  );

  PlannedExpense copyWith({String? lastPaidKey}) => PlannedExpense(
    id: id,
    name: name,
    amount: amount,
    categoryId: categoryId,
    dayOfMonth: dayOfMonth,
    lastPaidKey: lastPaidKey ?? this.lastPaidKey,
  );
}
