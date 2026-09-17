import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_personales/models/debt.dart';

void main() {
  group('computeInstallments mensual', () {
    test('genera una cuota por mes desde la fecha inicial', () {
      final schedule = computeInstallments(
        total: 3000,
        frequency: PaymentFrequency.monthly,
        start: DateTime(2026, 1, 15),
        numberOfPayments: 3,
      );
      expect(schedule.length, 3);
      expect(schedule[0].date, DateTime(2026, 1, 15));
      expect(schedule[1].date, DateTime(2026, 2, 15));
      expect(schedule[2].date, DateTime(2026, 3, 15));
      expect(schedule.every((i) => i.amount == 1000), isTrue);
    });

    test('ajusta el día 31 a meses con menos días', () {
      final schedule = computeInstallments(
        total: 620,
        frequency: PaymentFrequency.monthly,
        start: DateTime(2026, 1, 31),
        numberOfPayments: 2,
      );
      expect(schedule[0].date, DateTime(2026, 1, 31));
      expect(schedule[1].date, DateTime(2026, 2, 28));
      expect(schedule[0].amount + schedule[1].amount, 620);
    });

    test('la última cuota absorbe el redondeo', () {
      final schedule = computeInstallments(
        total: 100,
        frequency: PaymentFrequency.monthly,
        start: DateTime(2026, 1, 1),
        numberOfPayments: 3,
      );
      expect(schedule[0].amount, closeTo(33.33, 0.001));
      expect(schedule[2].amount, closeTo(33.34, 0.001));
      final sum = schedule.fold<double>(0, (s, i) => s + i.amount);
      expect(sum, closeTo(100, 0.001));
    });
  });

  group('computeInstallments quincenal y semanal', () {
    test('cada 15 días desde la fecha inicial', () {
      final schedule = computeInstallments(
        total: 600,
        frequency: PaymentFrequency.biweekly,
        start: DateTime(2026, 9, 1),
        numberOfPayments: 4,
      );
      expect(schedule.length, 4);
      expect(schedule[0].date, DateTime(2026, 9, 1));
      expect(schedule[1].date, DateTime(2026, 9, 16));
      expect(schedule[2].date, DateTime(2026, 10, 1));
      expect(schedule.every((i) => i.amount == 150), isTrue);
    });

    test('cada 7 días desde la fecha inicial', () {
      final schedule = computeInstallments(
        total: 700,
        frequency: PaymentFrequency.weekly,
        start: DateTime(2026, 9, 1),
        numberOfPayments: 4,
      );
      expect(schedule.length, 4);
      expect(schedule[1].date, DateTime(2026, 9, 8));
      expect(schedule[3].date, DateTime(2026, 9, 22));
    });
  });

  group('pago único', () {
    test('una sola cuota por el total', () {
      final schedule = computeInstallments(
        total: 2500,
        frequency: PaymentFrequency.oneTime,
        start: DateTime(2026, 12, 10),
        numberOfPayments: 5,
      );
      expect(schedule.length, 1);
      expect(schedule.single.amount, 2500);
    });
  });

  group('isInstallmentPaid', () {
    test('marca pagadas de forma acumulada según paidAmount', () {
      final debt = Debt(
        id: 'd1',
        name: 'Préstamo',
        totalAmount: 3000,
        paidAmount: 1500,
        categoryId: 'otros',
        startDate: DateTime(2026, 1, 15),
        frequency: PaymentFrequency.monthly,
        numberOfPayments: 3,
      );
      final schedule = debt.installments;
      expect(debt.isInstallmentPaid(schedule[0]), isTrue);
      expect(debt.isInstallmentPaid(schedule[1]), isFalse);
      expect(debt.isInstallmentPaid(schedule[2]), isFalse);
    });

    test('con dos cuotas pagadas, las dos primeras quedan liquidadas', () {
      final debt = Debt(
        id: 'd1',
        name: 'Préstamo',
        totalAmount: 3000,
        paidAmount: 2000,
        categoryId: 'otros',
        startDate: DateTime(2026, 1, 15),
        frequency: PaymentFrequency.monthly,
        numberOfPayments: 3,
      );
      final schedule = debt.installments;
      expect(debt.isInstallmentPaid(schedule[0]), isTrue);
      expect(debt.isInstallmentPaid(schedule[1]), isTrue);
      expect(debt.isInstallmentPaid(schedule[2]), isFalse);
    });
  });

  group('legacy (sin frecuencia guardada)', () {
    test('fromMap migra a pago único con dueDate', () {
      final map = {
        'id': 'x',
        'name': 'Vieja',
        'totalAmount': 500,
        'paidAmount': 100,
        'categoryId': 'otros',
        'dueDate': DateTime(2026, 5, 1).millisecondsSinceEpoch,
      };
      final debt = Debt.fromMap(map);
      expect(debt.frequency, PaymentFrequency.oneTime);
      expect(debt.startDate, DateTime(2026, 5, 1));
      expect(debt.installmentCount, 1);
    });
  });
}
