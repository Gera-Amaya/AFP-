import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/category.dart';
import '../models/debt.dart';
import '../models/plan_config.dart';
import '../models/planned_expense.dart';
import '../models/savings_goal.dart';
import '../models/transaction.dart';
import '../utils/format.dart';

const boxNameCategories = 'categories';
const boxNameTransactions = 'transactions';
const boxNamePlannedExpenses = 'planned_expenses';
const boxNameDebts = 'debts';
const boxNamePlanConfig = 'plan_config';
const boxNameSavingsGoals = 'savings_goals';

Future<void> initStorage() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    Hive.init(null);
  } else {
    await Hive.initFlutter();
  }
  await Hive.openBox<Map>(boxNameCategories);
  await Hive.openBox<Map>(boxNameTransactions);
  await Hive.openBox<Map>(boxNamePlannedExpenses);
  await Hive.openBox<Map>(boxNameDebts);
  await Hive.openBox<Map>(boxNamePlanConfig);
  await Hive.openBox<Map>(boxNameSavingsGoals);
}

class FinanceRepository {
  FinanceRepository._internal();

  static final FinanceRepository instance = FinanceRepository._internal();

  Box<Map> get _categoriesBox => Hive.box(boxNameCategories);
  Box<Map> get _transactionsBox => Hive.box(boxNameTransactions);
  Box<Map> get _plannedExpensesBox => Hive.box(boxNamePlannedExpenses);
  Box<Map> get _debtsBox => Hive.box(boxNameDebts);
  Box<Map> get _planConfigBox => Hive.box(boxNamePlanConfig);
  Box<Map> get _savingsGoalsBox => Hive.box(boxNameSavingsGoals);

  ValueListenable<Box<Map>> get categoriesListenable =>
      _categoriesBox.listenable();
  ValueListenable<Box<Map>> get transactionsListenable =>
      _transactionsBox.listenable();
  ValueListenable<Box<Map>> get plannedExpensesListenable =>
      _plannedExpensesBox.listenable();
  ValueListenable<Box<Map>> get debtsListenable => _debtsBox.listenable();
  ValueListenable<Box<Map>> get planConfigListenable =>
      _planConfigBox.listenable();
  ValueListenable<Box<Map>> get savingsGoalsListenable =>
      _savingsGoalsBox.listenable();

  Map<String, dynamic> _cast(Map raw) => Map<String, dynamic>.from(raw);

  // ---------- Categorías ----------

  List<Category> getCategories() =>
      _categoriesBox.values.map((m) => Category.fromMap(_cast(m))).toList();

  List<Category> getCategoriesByType(CategoryType type) =>
      _categoriesBox.values
          .map((m) => Category.fromMap(_cast(m)))
          .where((c) => c.type == type)
          .toList();

  Category? getCategory(String id) {
    final raw = _categoriesBox.get(id);
    return raw == null ? null : Category.fromMap(_cast(raw));
  }

  String getCategoryName(String id) {
    final c = getCategory(id);
    return c?.name ?? 'Sin categoría';
  }

  Future<void> saveCategory(Category category) =>
      _categoriesBox.put(category.id, category.toMap());

  Future<void> deleteCategory(String id) async {
    final used = _transactionsBox.values
        .map((m) => Transaction.fromMap(_cast(m)))
        .any((t) => t.categoryId == id);
    if (used) {
      throw Exception(
        'No se puede eliminar una categoría con movimientos asociados.',
      );
    }
    final usedByExpenses = _plannedExpensesBox.values
        .map((m) => PlannedExpense.fromMap(_cast(m)))
        .any((e) => e.categoryId == id);
    if (usedByExpenses) {
      throw Exception(
        'No se puede eliminar: hay compromisos que usan esta categoría.',
      );
    }
    final usedByDebts = _debtsBox.values
        .map((m) => Debt.fromMap(_cast(m)))
        .any((d) => d.categoryId == id);
    if (usedByDebts) {
      throw Exception(
        'No se puede eliminar: hay deudas que usan esta categoría.',
      );
    }
    final usedByGoals = _savingsGoalsBox.values
        .map((m) => SavingsGoal.fromMap(_cast(m)))
        .any((g) => g.categoryId == id);
    if (usedByGoals) {
      throw Exception(
        'No se puede eliminar: hay metas de ahorro que usan esta categoría.',
      );
    }
    await _categoriesBox.delete(id);
  }

  // ---------- Transacciones ----------

  List<Transaction> getTransactions() =>
      _transactionsBox.values
          .map((m) => Transaction.fromMap(_cast(m)))
          .toList();

  List<Transaction> getTransactionsBetween(DateTime start, DateTime end) =>
      getTransactions().where((t) {
        final d = t.date;
        return !d.isBefore(start) && d.isBefore(end.add(const Duration(days: 1)));
      }).toList();

  Future<void> saveTransaction(Transaction transaction) =>
      _transactionsBox.put(transaction.id, transaction.toMap());

  Future<void> deleteTransaction(String id) => _transactionsBox.delete(id);

  // ---------- Resumen ----------

  double getBalance() {
    double balance = 0;
    for (final t in getTransactions()) {
      balance += t.type == CategoryType.income ? t.amount : -t.amount;
    }
    return balance;
  }

  double getMonthIncome(DateTime month) =>
      _monthTotal(month, CategoryType.income);

  double getMonthExpense(DateTime month) =>
      _monthTotal(month, CategoryType.expense);

  double _monthTotal(DateTime month, CategoryType type) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(
      month.year,
      month.month + 1,
    ).subtract(const Duration(days: 1));
    return getTransactionsBetween(
      start,
      end,
    ).where((t) => t.type == type).fold(0, (sum, t) => sum + t.amount);
  }

  // ---------- Compromisos (gastos futuros) ----------

  List<PlannedExpense> getPlannedExpenses() =>
      _plannedExpensesBox.values
          .map((m) => PlannedExpense.fromMap(_cast(m)))
          .toList();

  Future<void> savePlannedExpense(PlannedExpense expense) =>
      _plannedExpensesBox.put(expense.id, expense.toMap());

  Future<void> deletePlannedExpense(String id) =>
      _plannedExpensesBox.delete(id);

  Future<void> markPlannedExpensePaid(PlannedExpense expense) async {
    final key = currentMonthKey(DateTime.now());
    if (expense.lastPaidKey == key) return;
    await saveTransaction(
      Transaction(
        id: const Uuid().v4(),
        type: CategoryType.expense,
        amount: expense.amount,
        categoryId: expense.categoryId,
        description: '${expense.name} (pago de compromiso)',
        date: DateTime.now(),
      ),
    );
    await savePlannedExpense(expense.copyWith(lastPaidKey: key));
  }

  // ---------- Deudas ----------

  List<Debt> getDebts() =>
      _debtsBox.values.map((m) => Debt.fromMap(_cast(m))).toList();

  Future<void> saveDebt(Debt debt) => _debtsBox.put(debt.id, debt.toMap());

  Future<void> deleteDebt(String id) => _debtsBox.delete(id);

  Future<void> payDebt(Debt debt, double amount, {String? description}) async {
    await saveTransaction(
      Transaction(
        id: const Uuid().v4(),
        type: CategoryType.expense,
        amount: amount,
        categoryId: debt.categoryId,
        description: description ?? '${debt.name} (abono)',
        date: DateTime.now(),
      ),
    );
    await saveDebt(debt.copyWith(paidAmount: debt.paidAmount + amount));
  }

  // ---------- Configuración del plan ----------

  PlanConfig getPlanConfig() {
    final raw = _planConfigBox.get('config');
    return raw == null ? const PlanConfig() : PlanConfig.fromMap(_cast(raw));
  }

  Future<void> savePlanConfig(PlanConfig config) =>
      _planConfigBox.put('config', config.toMap());

  // ---------- Metas de ahorro ----------

  List<SavingsGoal> getSavingsGoals() =>
      _savingsGoalsBox.values
          .map((m) => SavingsGoal.fromMap(_cast(m)))
          .toList();

  Future<void> saveSavingsGoal(SavingsGoal goal) =>
      _savingsGoalsBox.put(goal.id, goal.toMap());

  Future<void> deleteSavingsGoal(String id) => _savingsGoalsBox.delete(id);

  double totalGoalTargets() =>
      getSavingsGoals().fold(0, (sum, g) => sum + g.targetAmount);

  double totalGoalSaved() =>
      getSavingsGoals().fold(0, (sum, g) => sum + g.savedAmount);

  Future<void> contributeToGoal(SavingsGoal goal, double amount) async {
    if (amount <= 0 || goal.isAchieved) return;
    final effective = amount > goal.remaining ? goal.remaining : amount;
    await saveTransaction(
      Transaction(
        id: const Uuid().v4(),
        type: CategoryType.expense,
        amount: effective,
        categoryId: goal.categoryId,
        tags: const ['meta'],
        description: '${goal.name} (aportación de ahorro)',
        date: DateTime.now(),
      ),
    );
    await saveSavingsGoal(
      goal.copyWith(savedAmount: goal.savedAmount + effective),
    );
  }

  // ---------- Respaldo (export/import) ----------

  Map<String, dynamic> exportAll() => {
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'categories': _categoriesBox.values.map(_cast).toList(),
    'transactions': _transactionsBox.values.map(_cast).toList(),
    'planned_expenses': _plannedExpensesBox.values.map(_cast).toList(),
    'debts': _debtsBox.values.map(_cast).toList(),
    'savings_goals': _savingsGoalsBox.values.map(_cast).toList(),
    'plan_config': _planConfigBox.get('config') == null
        ? null
        : _cast(_planConfigBox.get('config')!),
  };

  Future<void> importAll(Map<String, dynamic> data) async {
    List<Map<String, dynamic>> readList(String key) {
      final raw = data[key];
      if (raw is! List) {
        throw FormatException('Respaldo inválido: falta "$key" o no es una lista.');
      }
      return [
        for (final item in raw)
          if (item is Map)
            _cast(item)
          else
            throw const FormatException('Respaldo inválido: entrada corrupta.'),
      ];
    }

    final categories = readList('categories');
    final transactions = readList('transactions');
    final plannedExpenses = readList('planned_expenses');
    final debts = readList('debts');

    List<Map<String, dynamic>> readListOrEmpty(String key) {
      final raw = data[key];
      if (raw == null) return const [];
      if (raw is! List) {
        throw FormatException(
          'Respaldo inválido: "$key" o no es una lista.',
        );
      }
      return [
        for (final item in raw)
          if (item is Map)
            _cast(item)
          else
            throw const FormatException(
              'Respaldo inválido: entrada corrupta.',
            ),
      ];
    }

    final savingsGoals = readListOrEmpty('savings_goals');

    final config = data['plan_config'] is Map
        ? _cast(data['plan_config']! as Map)
        : null;

    await _categoriesBox.clear();
    await _transactionsBox.clear();
    await _plannedExpensesBox.clear();
    await _debtsBox.clear();
    await _savingsGoalsBox.clear();
    await _planConfigBox.clear();

    for (final c in categories) {
      await _categoriesBox.put(c['id'] as String, c);
    }
    for (final t in transactions) {
      await _transactionsBox.put(t['id'] as String, t);
    }
    for (final e in plannedExpenses) {
      await _plannedExpensesBox.put(e['id'] as String, e);
    }
    for (final d in debts) {
      await _debtsBox.put(d['id'] as String, d);
    }
    for (final g in savingsGoals) {
      await _savingsGoalsBox.put(g['id'] as String, g);
    }
    if (config != null) {
      await _planConfigBox.put('config', config);
    }
  }

  // ---------- Cálculos de ahorro ----------

  double plannedExpensesTotal() =>
      getPlannedExpenses().fold(0, (sum, e) => sum + e.amount);

  double debtsDueTotal(DateTime month) {
    var total = 0.0;
    for (final debt in getDebts()) {
      for (final inst in debt.installments) {
        if (!debt.isInstallmentPaid(inst) && !isAfterMonth(inst.date, month)) {
          total += inst.amount;
        }
      }
    }
    return total;
  }

  List<DebtInstallment> pendingInstallmentsForMonth(Debt debt, DateTime month) {
    return [
      for (final inst in debt.installments)
        if (!debt.isInstallmentPaid(inst) &&
            (isBeforeMonth(inst.date, month) ||
                (inst.date.year == month.year &&
                    inst.date.month == month.month)))
          inst,
    ];
  }

  double availableForSavings(DateTime month) =>
      getPlanConfig().monthlyIncome -
      plannedExpensesTotal() -
      debtsDueTotal(month);

  static bool isBeforeMonth(DateTime date, DateTime month) =>
      date.year < month.year ||
      (date.year == month.year && date.month < month.month);

  static bool isAfterMonth(DateTime date, DateTime month) =>
      date.year > month.year ||
      (date.year == month.year && date.month > month.month);

  double getMonthSavingsContributions(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(
      month.year,
      month.month + 1,
    ).subtract(const Duration(days: 1));
    return getTransactionsBetween(
      start,
      end,
    ).where((t) => t.type == CategoryType.expense && t.tags.contains('meta'))
        .fold(0, (sum, t) => sum + t.amount);
  }

  // ---------- Predeterminadas ----------

  List<Category> defaultCategories() {
    const defaults = [
      ('sueldo', 'Sueldo', 'payments', CategoryType.income, 0xFF2E7D32),
      (
        'otros-ingresos',
        'Otros ingresos',
        'savings',
        CategoryType.income,
        0xFF0277BD,
      ),
      ('comida', 'Comida', 'restaurant', CategoryType.expense, 0xFFE53935),
      (
        'super',
        'Supermercado',
        'shopping_cart',
        CategoryType.expense,
        0xFF8E24AA,
      ),
      ('renta', 'Renta', 'home', CategoryType.expense, 0xFFFF8F00),
      ('servicios', 'Servicios', 'bolt', CategoryType.expense, 0xFF00897B),
      (
        'transporte',
        'Transporte',
        'directions_bus',
        CategoryType.expense,
        0xFF3949AB,
      ),
      ('salud', 'Salud', 'local_hospital', CategoryType.expense, 0xFFD81B60),
      (
        'entretenimiento',
        'Entretenimiento',
        'movie',
        CategoryType.expense,
        0xFFF4511E,
      ),
      ('compras', 'Compras', 'shopping_bag', CategoryType.expense, 0xFF6D4C41),
      ('otros', 'Otros', 'category', CategoryType.expense, 0xFF757575),
    ];
    return [
      for (final (id, name, icon, type, color) in defaults)
        Category(id: id, name: name, type: type, icon: icon, colorValue: color),
    ];
  }

  Future<void> seedDefaultCategories() async {
    if (_categoriesBox.isNotEmpty) return;
    for (final c in defaultCategories()) {
      await saveCategory(c);
    }
  }
}
