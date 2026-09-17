enum PaymentFrequency { weekly, biweekly, monthly, oneTime }

extension PaymentFrequencyX on PaymentFrequency {
  String get label => switch (this) {
    PaymentFrequency.weekly => 'Semanal (cada 7 días)',
    PaymentFrequency.biweekly => 'Quincenal (cada 15 días)',
    PaymentFrequency.monthly => 'Mensual',
    PaymentFrequency.oneTime => 'Fecha específica',
  };

  String get shortLabel => switch (this) {
    PaymentFrequency.weekly => 'cada semana',
    PaymentFrequency.biweekly => 'cada 15 días',
    PaymentFrequency.monthly => 'cada mes',
    PaymentFrequency.oneTime => 'pago único',
  };
}

class DebtInstallment {
  final DateTime date;
  final double amount;

  const DebtInstallment({required this.date, required this.amount});
}

List<DebtInstallment> computeInstallments({
  required double total,
  required PaymentFrequency frequency,
  required DateTime start,
  required int numberOfPayments,
}) {
  final count = frequency == PaymentFrequency.oneTime ? 1 : numberOfPayments;
  if (count < 1) return [];
  final dates = <DateTime>[];
  switch (frequency) {
    case PaymentFrequency.weekly:
      for (int i = 0; i < count; i++) {
        dates.add(start.add(Duration(days: 7 * i)));
      }
    case PaymentFrequency.biweekly:
      for (int i = 0; i < count; i++) {
        dates.add(start.add(Duration(days: 15 * i)));
      }
    case PaymentFrequency.monthly:
      for (int i = 0; i < count; i++) {
        final year = start.year;
        final month = start.month + i;
        final lastDay = DateTime(year, month + 1, 0).day;
        final day = start.day > lastDay ? lastDay : start.day;
        dates.add(DateTime(year, month, day));
      }
    case PaymentFrequency.oneTime:
      dates.add(start);
  }
  final baseQuota = _round2(total / count);
  return [
    for (int i = 0; i < dates.length; i++)
      DebtInstallment(
        date: dates[i],
        amount:
            i == dates.length - 1
                ? _round2((total - baseQuota * (dates.length - 1)).clamp(0, total))
                : baseQuota,
      ),
  ];
}

double _round2(double value) => (value * 100).roundToDouble() / 100;

class Debt {
  final String id;
  final String name;
  final double totalAmount;
  final double paidAmount;
  final String categoryId;
  final DateTime startDate;
  final PaymentFrequency frequency;
  final int numberOfPayments;
  final String notes;

  const Debt({
    required this.id,
    required this.name,
    required this.totalAmount,
    this.paidAmount = 0,
    required this.categoryId,
    required this.startDate,
    this.frequency = PaymentFrequency.oneTime,
    this.numberOfPayments = 1,
    this.notes = '',
  });

  double get remaining =>
      (totalAmount - paidAmount) < 0 ? 0 : totalAmount - paidAmount;

  double get progress =>
      totalAmount <= 0 ? 0 : (paidAmount / totalAmount).clamp(0, 1);

  bool get isPaidOff => remaining <= 0;

  int get installmentCount =>
      frequency == PaymentFrequency.oneTime ? 1 : numberOfPayments;

  List<DebtInstallment> get installments => computeInstallments(
    total: totalAmount,
    frequency: frequency,
    start: startDate,
    numberOfPayments: numberOfPayments,
  );

  bool isInstallmentPaid(DebtInstallment target) {
    final schedule = installments;
    final index = schedule.indexWhere((i) => i.date == target.date);
    if (index < 0) return false;
    double cumulative = 0;
    for (int i = 0; i <= index; i++) {
      cumulative += schedule[i].amount;
    }
    return paidAmount + 0.001 >= cumulative;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'totalAmount': totalAmount,
    'paidAmount': paidAmount,
    'categoryId': categoryId,
    'startDate': startDate.millisecondsSinceEpoch,
    'frequency': frequency.name,
    'numberOfPayments': numberOfPayments,
    'notes': notes,
  };

  factory Debt.fromMap(Map<String, dynamic> map) {
    final rawFrequency = map['frequency'] as String?;
    final frequency =
        rawFrequency == null
            ? PaymentFrequency.oneTime
            : PaymentFrequency.values.firstWhere(
              (e) => e.name == rawFrequency,
              orElse: () => PaymentFrequency.oneTime,
            );
    final rawStart =
        (map['startDate'] ?? map['dueDate']) as int? ??
        DateTime.now().millisecondsSinceEpoch;
    final count =
        (map['numberOfPayments'] as num?)?.toInt() ??
        (frequency == PaymentFrequency.oneTime ? 1 : 1);
    return Debt(
      id: map['id'] as String,
      name: map['name'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      paidAmount: (map['paidAmount'] as num).toDouble(),
      categoryId: map['categoryId'] as String,
      startDate: DateTime.fromMillisecondsSinceEpoch(rawStart),
      frequency: frequency,
      numberOfPayments: count,
      notes: (map['notes'] as String?) ?? '',
    );
  }

  Debt copyWith({double? paidAmount}) => Debt(
    id: id,
    name: name,
    totalAmount: totalAmount,
    paidAmount: paidAmount ?? this.paidAmount,
    categoryId: categoryId,
    startDate: startDate,
    frequency: frequency,
    numberOfPayments: numberOfPayments,
    notes: notes,
  );
}
