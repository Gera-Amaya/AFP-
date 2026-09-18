import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:finanzas_personales/data/finance_repository.dart';
import 'package:finanzas_personales/models/category.dart';
import 'package:finanzas_personales/models/savings_goal.dart';
import 'package:finanzas_personales/models/transaction.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('afp_goal_test');
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

  SavingsGoal goal({
    double target = 10000,
    double saved = 0,
    double? contribution,
    DateTime? deadline,
  }) => SavingsGoal(
    id: 'g1',
    name: 'Viaje',
    targetAmount: target,
    savedAmount: saved,
    categoryId: 'viajes',
    deadline: deadline,
    monthlyContribution: contribution,
  );

  group('cálculos del modelo', () {
    test('remaining y progress', () {
      final g = goal(target: 10000, saved: 2500);
      expect(g.remaining, 7500);
      expect(g.progress, closeTo(0.25, 0.001));
      expect(g.isAchieved, isFalse);
    });

    test('progress nunca supera 1 y remaining nunca baja de 0', () {
      final g = goal(target: 10000, saved: 12000);
      expect(g.remaining, 0);
      expect(g.progress, 1);
      expect(g.isAchieved, isTrue);
    });

    test('monthsToDeadline redondea hacia arriba al mes en curso', () {
      final from = DateTime(2026, 3, 10);
      expect(goal(deadline: DateTime(2026, 4, 1)).monthsToDeadline(from), 1);
      expect(goal(deadline: DateTime(2026, 4, 10)).monthsToDeadline(from), 2);
    });

    test('monthsToDeadline nunca baja de 1 y es 0 sin fecha', () {
      final from = DateTime(2026, 6, 10);
      expect(goal(deadline: DateTime(2026, 4, 10)).monthsToDeadline(from), 1);
      expect(goal().monthsToDeadline(from), 0);
    });

    test('neededMonthlyByDeadline divide lo faltante entre los meses', () {
      final from = DateTime(2026, 3, 10);
      final g = goal(
        target: 4000,
        saved: 1000,
        deadline: DateTime(2026, 5, 15),
      );
      expect(g.remaining, 3000);
      expect(g.neededMonthlyByDeadline(from), closeTo(1000, 0.001));
    });

    test('neededMonthlyByDeadline es null si está lograda', () {
      final from = DateTime(2026, 3, 10);
      final g = goal(
        target: 1000,
        saved: 1000,
        deadline: DateTime(2026, 4, 1),
      );
      expect(g.neededMonthlyByDeadline(from), isNull);
    });

    test('monthsToReach usa los meses exactos necesarios', () {
      expect(goal(target: 10000, saved: 5500, contribution: 2000).monthsToReach, 3);
      expect(goal(target: 10000, contribution: 2000).monthsToReach, 5);
      expect(goal().monthsToReach, isNull);
      expect(goal(target: 1000, saved: 1000, contribution: 500).monthsToReach, isNull);
    });
  });

  group('aportaciones a metas', () {
    test('contribuir crea un gasto real con tag meta y actualiza el ahorro', () async {
      final repo = FinanceRepository.instance;
      final g = goal(target: 10000, saved: 2000);
      await repo.saveSavingsGoal(g);
      await repo.contributeToGoal(g, 1500);

      final goalAfter = repo.getSavingsGoals().single;
      expect(goalAfter.savedAmount, 3500);

      final tx = repo.getTransactions().single;
      expect(tx.type, CategoryType.expense);
      expect(tx.amount, 1500);
      expect(tx.tags, ['meta']);
      expect(tx.categoryId, 'viajes');
      expect(tx.description, 'Viaje (aportación de ahorro)');
    });

    test('la aportación se limita al monto que falta', () async {
      final repo = FinanceRepository.instance;
      final g = goal(target: 10000, saved: 9000);
      await repo.saveSavingsGoal(g);

      await repo.contributeToGoal(g, 5000);

      final goalAfter = repo.getSavingsGoals().single;
      expect(goalAfter.savedAmount, 10000);
      expect(goalAfter.isAchieved, isTrue);

      final tx = repo.getTransactions().single;
      expect(tx.amount, 1000);
    });

    test('cantidad inválida o meta ya lograda no crean nada', () async {
      final repo = FinanceRepository.instance;
      final g = goal(target: 10000, saved: 0);
      await repo.saveSavingsGoal(g);
      await repo.contributeToGoal(g, 0);
      expect(repo.getTransactions(), isEmpty);

      final achieved = goal(target: 1000, saved: 1000);
      await repo.saveSavingsGoal(achieved);
      await repo.contributeToGoal(achieved, 500);
      expect(repo.getTransactions(), isEmpty);
      expect(repo.getSavingsGoals().single.savedAmount, 1000);
    });
  });

  group('ahorro en metas por mes', () {
    test('getMonthSavingsContributions filtra por mes y tag meta', () async {
      final repo = FinanceRepository.instance;
      Future<void> upsert(
        String id,
        CategoryType type,
        double amount,
        List<String> tags,
        DateTime date,
      ) => repo.saveTransaction(
        Transaction(
          id: id,
          type: type,
          amount: amount,
          categoryId: 'viajes',
          tags: tags,
          description: '',
          date: date,
        ),
      );

      await upsert('a', CategoryType.expense, 500, ['meta'], DateTime(2026, 3, 10));
      await upsert('b', CategoryType.expense, 300, ['meta'], DateTime(2026, 4, 2));
      await upsert('c', CategoryType.expense, 700, [], DateTime(2026, 3, 15));
      await upsert('d', CategoryType.income, 100, ['meta'], DateTime(2026, 3, 20));

      expect(repo.getMonthSavingsContributions(DateTime(2026, 3)), 500);
      expect(repo.getMonthSavingsContributions(DateTime(2026, 4)), 300);
      expect(repo.getMonthSavingsContributions(DateTime(2026, 5)), 0);
    });
  });
}