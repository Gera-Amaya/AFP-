import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:hive_flutter/hive_flutter.dart';

import '../models/category.dart';
import '../models/transaction.dart';

const boxNameCategories = 'categories';
const boxNameTransactions = 'transactions';

Future<void> initStorage() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    Hive.init(null);
  } else {
    await Hive.initFlutter();
  }
  await Hive.openBox<Map>(boxNameCategories);
  await Hive.openBox<Map>(boxNameTransactions);
}

class FinanceRepository {
  FinanceRepository._internal();

  static final FinanceRepository instance = FinanceRepository._internal();

  Box<Map> get _categoriesBox => Hive.box(boxNameCategories);
  Box<Map> get _transactionsBox => Hive.box(boxNameTransactions);

  ValueListenable<Box<Map>> get categoriesListenable =>
      _categoriesBox.listenable();
  ValueListenable<Box<Map>> get transactionsListenable =>
      _transactionsBox.listenable();

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
        return !d.isBefore(start) && !d.isAfter(end);
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
