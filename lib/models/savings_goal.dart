class SavingsGoal {
  final String id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final String categoryId;
  final DateTime? deadline;
  final double? monthlyContribution;

  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.savedAmount = 0,
    required this.categoryId,
    this.deadline,
    this.monthlyContribution,
  });

  double get remaining => (targetAmount - savedAmount) < 0
      ? 0
      : targetAmount - savedAmount;

  double get progress =>
      targetAmount <= 0 ? 0 : (savedAmount / targetAmount).clamp(0, 1);

  bool get isAchieved => savedAmount >= targetAmount;

  int monthsToDeadline([DateTime? from]) {
    final d = deadline;
    if (d == null) return 0;
    final now = from ?? DateTime.now();
    final months =
        (d.year - now.year) * 12 +
        (d.month - now.month) +
        (d.day >= now.day ? 1 : 0);
    return months < 1 ? 1 : months;
  }

  double? neededMonthlyByDeadline([DateTime? from]) {
    if (deadline == null || remaining <= 0) return null;
    final months = monthsToDeadline(from);
    return months > 0 ? remaining / months : null;
  }

  int? get monthsToReach {
    final contribution = monthlyContribution;
    if (contribution == null || contribution <= 0 || remaining <= 0) return null;
    return (remaining / contribution).ceil();
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'targetAmount': targetAmount,
    'savedAmount': savedAmount,
    'categoryId': categoryId,
    'deadline': deadline?.millisecondsSinceEpoch,
    'monthlyContribution': monthlyContribution,
  };

  factory SavingsGoal.fromMap(Map<String, dynamic> map) => SavingsGoal(
    id: map['id'] as String,
    name: map['name'] as String,
    targetAmount: (map['targetAmount'] as num).toDouble(),
    savedAmount: (map['savedAmount'] as num?)?.toDouble() ?? 0,
    categoryId: map['categoryId'] as String,
    deadline: map['deadline'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(map['deadline'] as int),
    monthlyContribution: (map['monthlyContribution'] as num?)?.toDouble(),
  );

  SavingsGoal copyWith({double? savedAmount}) => SavingsGoal(
    id: id,
    name: name,
    targetAmount: targetAmount,
    savedAmount: savedAmount ?? this.savedAmount,
    categoryId: categoryId,
    deadline: deadline,
    monthlyContribution: monthlyContribution,
  );
}