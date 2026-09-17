class PlanConfig {
  final double monthlyIncome;
  final double savingsGoal;

  const PlanConfig({this.monthlyIncome = 0, this.savingsGoal = 0});

  Map<String, dynamic> toMap() => {
    'monthlyIncome': monthlyIncome,
    'savingsGoal': savingsGoal,
  };

  factory PlanConfig.fromMap(Map<String, dynamic> map) => PlanConfig(
    monthlyIncome: (map['monthlyIncome'] as num?)?.toDouble() ?? 0,
    savingsGoal: (map['savingsGoal'] as num?)?.toDouble() ?? 0,
  );
}
