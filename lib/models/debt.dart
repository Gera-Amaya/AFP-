class Debt {
  final String id;
  final String name;
  final double totalAmount;
  final double paidAmount;
  final String categoryId;
  final DateTime dueDate;
  final String notes;

  const Debt({
    required this.id,
    required this.name,
    required this.totalAmount,
    this.paidAmount = 0,
    required this.categoryId,
    required this.dueDate,
    this.notes = '',
  });

  double get remaining =>
      (totalAmount - paidAmount) < 0 ? 0 : totalAmount - paidAmount;

  double get progress =>
      totalAmount <= 0 ? 0 : (paidAmount / totalAmount).clamp(0, 1);

  bool get isPaidOff => remaining <= 0;

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'totalAmount': totalAmount,
    'paidAmount': paidAmount,
    'categoryId': categoryId,
    'dueDate': dueDate.millisecondsSinceEpoch,
    'notes': notes,
  };

  factory Debt.fromMap(Map<String, dynamic> map) => Debt(
    id: map['id'] as String,
    name: map['name'] as String,
    totalAmount: (map['totalAmount'] as num).toDouble(),
    paidAmount: (map['paidAmount'] as num).toDouble(),
    categoryId: map['categoryId'] as String,
    dueDate: DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int),
    notes: (map['notes'] as String?) ?? '',
  );

  Debt copyWith({double? paidAmount}) => Debt(
    id: id,
    name: name,
    totalAmount: totalAmount,
    paidAmount: paidAmount ?? this.paidAmount,
    categoryId: categoryId,
    dueDate: dueDate,
    notes: notes,
  );
}
