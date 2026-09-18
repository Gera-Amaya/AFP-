import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:finanzas_personales/data/finance_repository.dart';
import 'package:finanzas_personales/models/category.dart';
import 'package:finanzas_personales/models/debt.dart';
import 'package:finanzas_personales/models/plan_config.dart';
import 'package:finanzas_personales/models/planned_expense.dart';
import 'package:finanzas_personales/models/savings_goal.dart';
import 'package:finanzas_personales/models/transaction.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('afp_test');
    Hive.init(tempDir.path);
    await Hive.openBox<Map>(boxNameCategories);
    await Hive.openBox<Map>(boxNameTransactions);
    await Hive.openBox<Map>(boxNamePlannedExpenses);
    await Hive.openBox<Map>(boxNameDebts);
    await Hive.openBox<Map>(boxNamePlanConfig);
    await Hive.openBox<Map>(boxNameSavingsGoals);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('límites de fin de mes', () {
    test('transacción del último día del mes con hora cuenta en el mes', () async {
      final repo = FinanceRepository.instance;
      await repo.saveTransaction(
        Transaction(
          id: 't1',
          type: CategoryType.income,
          amount: 500,
          categoryId: 'sueldo',
          description: '',
          date: DateTime(2026, 3, 31, 23, 30),
        ),
      );
      expect(repo.getMonthIncome(DateTime(2026, 3)), 500);
      expect(repo.getMonthIncome(DateTime(2026, 4)), 0);
      expect(repo.getBalance(), 500);
    });

    test('transacción del primer día del mes pertenece solo a ese mes', () async {
      final repo = FinanceRepository.instance;
      await repo.saveTransaction(
        Transaction(
          id: 't2',
          type: CategoryType.expense,
          amount: 100,
          categoryId: 'comida',
          description: '',
          date: DateTime(2026, 4, 1, 0, 0),
        ),
      );
      expect(repo.getMonthExpense(DateTime(2026, 4)), 100);
      expect(repo.getMonthExpense(DateTime(2026, 3)), 0);
      expect(repo.getMonthExpense(DateTime(2026, 5)), 0);
    });

    test('getTransactionsBetween incluye el día completo del end', () async {
      final repo = FinanceRepository.instance;
      await repo.saveTransaction(
        Transaction(
          id: 't3',
          type: CategoryType.expense,
          amount: 50,
          categoryId: 'comida',
          description: '',
          date: DateTime(2026, 6, 30, 23, 59),
        ),
      );
      final between = repo.getTransactionsBetween(
        DateTime(2026, 6),
        DateTime(2026, 7, 1).subtract(const Duration(days: 1)),
      );
      expect(between.length, 1);
    });
  });

  group('export/import', () {
    test('round-trip restaura todos los datos', () async {
      final repo = FinanceRepository.instance;
      await repo.saveCategory(
        const Category(
          id: 'comida',
          name: 'Comida',
          type: CategoryType.expense,
          icon: 'restaurant',
          colorValue: 0xFFE53935,
        ),
      );
      await repo.saveTransaction(
        Transaction(
          id: 't1',
          type: CategoryType.expense,
          amount: 100.5,
          categoryId: 'comida',
          tags: ['casa'],
          description: 'Mercado',
          date: DateTime(2026, 9, 10, 12),
        ),
      );
      await repo.savePlannedExpense(
        const PlannedExpense(
          id: 'p1',
          name: 'Renta',
          amount: 4000,
          categoryId: 'comida',
          dayOfMonth: 5,
        ),
      );
      await repo.saveDebt(
        Debt(
          id: 'd1',
          name: 'Tarjeta',
          totalAmount: 1000,
          categoryId: 'comida',
          startDate: DateTime(2026, 9, 1),
        ),
      );
      await repo.savePlanConfig(
        const PlanConfig(monthlyIncome: 10000, savingsGoal: 2000),
      );
      await repo.saveSavingsGoal(
        SavingsGoal(
          id: 'g1',
          name: 'Viaje',
          targetAmount: 12000,
          savedAmount: 4000,
          categoryId: 'comida',
          deadline: DateTime(2026, 12, 1),
          monthlyContribution: 1500,
        ),
      );

      final data = repo.exportAll();
      await repo.importAll(data);

      final categories = repo.getCategories();
      expect(categories.length, 1);
      expect(categories.single.name, 'Comida');

      final transactions = repo.getTransactions();
      expect(transactions.length, 1);
      expect(transactions.single.amount, 100.5);
      expect(transactions.single.tags, ['casa']);
      expect(transactions.single.description, 'Mercado');

      expect(repo.getPlannedExpenses().single.name, 'Renta');
      expect(repo.getPlannedExpenses().single.amount, 4000);
      expect(repo.getDebts().single.name, 'Tarjeta');
      expect(repo.getDebts().single.totalAmount, 1000);
      expect(repo.getPlanConfig().monthlyIncome, 10000);
      expect(repo.getPlanConfig().savingsGoal, 2000);

      final goal = repo.getSavingsGoals().single;
      expect(goal.name, 'Viaje');
      expect(goal.targetAmount, 12000);
      expect(goal.savedAmount, 4000);
      expect(goal.deadline, DateTime(2026, 12, 1));
      expect(goal.monthlyContribution, 1500);
    });

    test('importAll acepta respaldos antiguos sin savings_goals', () async {
      final data = <String, dynamic>{
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'categories': <Map<String, dynamic>>[],
        'transactions': <Map<String, dynamic>>[],
        'planned_expenses': <Map<String, dynamic>>[],
        'debts': <Map<String, dynamic>>[],
      };
      await FinanceRepository.instance.importAll(data);
      expect(FinanceRepository.instance.getSavingsGoals(), isEmpty);
    });

    test('importAll lanza FormatException con un respaldo inválido', () async {
      await expectLater(
        FinanceRepository.instance.importAll({'foo': 'bar'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('deudas pendientes', () {
    test('debtsDueTotal incluye cuotas vencidas no pagadas', () async {
      final repo = FinanceRepository.instance;
      final debt = Debt(
        id: 'd1',
        name: 'Tarjeta',
        totalAmount: 900,
        categoryId: 'comida',
        startDate: DateTime(2026, 1, 15),
        frequency: PaymentFrequency.monthly,
        numberOfPayments: 3,
      );
      await repo.saveDebt(debt);

      final feb = DateTime(2026, 2);
      final expected = debt.installments
          .where(
            (i) =>
                i.date.year < feb.year ||
                (i.date.year == feb.year && i.date.month <= feb.month),
          )
          .fold(0.0, (sum, i) => sum + i.amount);
      expect(repo.debtsDueTotal(feb), expected);
      expect(repo.debtsDueTotal(DateTime(2026, 4)), 900);
    });

    test('debtsDueTotal excluye cuotas pagadas y las del mes siguiente', () async {
      final repo = FinanceRepository.instance;
      final debt = Debt(
        id: 'd1',
        name: 'Tarjeta',
        totalAmount: 900,
        categoryId: 'comida',
        startDate: DateTime(2026, 1, 15),
        frequency: PaymentFrequency.monthly,
        numberOfPayments: 3,
      );
      final firstInstallment = debt.installments.first;
      await repo.saveDebt(debt.copyWith(paidAmount: firstInstallment.amount));

      final feb = DateTime(2026, 2);
      final expected = debt.installments
          .where(
            (i) =>
                i.date == firstInstallment.date
                    ? false
                    : i.date.year < feb.year ||
                          (i.date.year == feb.year &&
                              i.date.month <= feb.month),
          )
          .fold(0.0, (sum, i) => sum + i.amount);
      expect(repo.debtsDueTotal(feb), expected);
    });
  });
}