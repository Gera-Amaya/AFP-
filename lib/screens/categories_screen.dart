import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/finance_repository.dart';
import '../models/category.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/transaction_tile.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = FinanceRepository.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        actions: [
          IconButton(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add),
            tooltip: 'Nueva categoría',
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: repo.categoriesListenable,
        builder: (context, _, __) {
          return ValueListenableBuilder(
            valueListenable: repo.transactionsListenable,
            builder: (context, _, __) {
              final income = repo.getCategoriesByType(CategoryType.income);
              final expense = repo.getCategoriesByType(CategoryType.expense);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const _SectionTitle('Ingresos'),
                  const SizedBox(height: 8),
                  _CategorySection(categories: income),
                  const SizedBox(height: 20),
                  const _SectionTitle('Gastos'),
                  const SizedBox(height: 8),
                  _CategorySection(categories: expense),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, color: seedColor),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Para eliminar una categoría necesitas que no tenga movimientos asociados.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _showRestoreDefaults(context),
                            icon: const Icon(Icons.restore),
                            tooltip: 'Restaurar categorías predeterminadas',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showRestoreDefaults(BuildContext context) {
    final repo = FinanceRepository.instance;
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Restaurar categorías'),
            content: const Text(
              'Se agregarán las categorías predeterminadas que falten. ¿Continuar?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  final defaults = repo.defaultCategories();
                  for (final c in defaults) {
                    if (!repo.getCategories().any((e) => e.id == c.id)) {
                      await repo.saveCategory(c);
                    }
                  }
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('Restaurar'),
              ),
            ],
          ),
    );
  }

  void _openEditor(BuildContext context, [Category? category]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryEditorScreen(category: category),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.black54,
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final List<Category> categories;

  const _CategorySection({required this.categories});

  @override
  Widget build(BuildContext context) {
    return Card(
      child:
          categories.isEmpty
              ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Sin categorías.',
                  style: TextStyle(color: Colors.black45),
                ),
              )
              : Column(
                children: [
                  for (final c in categories)
                    ListTile(
                      leading: CategoryAvatar(category: c),
                      title: Text(
                        c.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _usageCount(c.id),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _openEditor(context, c),
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: Colors.black45,
                            ),
                            tooltip: 'Editar',
                          ),
                          IconButton(
                            onPressed: () => _confirmDelete(context, c),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: dangerColor,
                            ),
                            tooltip: 'Eliminar',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
    );
  }

  String _usageCount(String id) {
    final count =
        FinanceRepository.instance
            .getTransactions()
            .where((t) => t.categoryId == id)
            .length;
    return count == 0 ? '' : '$count movs.';
  }

  void _openEditor(BuildContext context, Category category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryEditorScreen(category: category),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Category category) {
    final repo = FinanceRepository.instance;
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Eliminar categoría'),
            content: Text('¿Eliminar la categoría "${category.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: dangerColor),
                onPressed: () async {
                  try {
                    await repo.deleteCategory(category.id);
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.toString().replaceAll('Exception: ', ''),
                          ),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }
}

class CategoryEditorScreen extends StatefulWidget {
  final Category? category;

  const CategoryEditorScreen({super.key, this.category});

  @override
  State<CategoryEditorScreen> createState() => _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends State<CategoryEditorScreen> {
  final _nameController = TextEditingController();
  CategoryType _type = CategoryType.expense;
  String _icon = 'category';
  int _color = 0xFF1E88E5;
  bool _isIncomeCategory = false;

  static const _colors = <int>[
    0xFFE53935,
    0xFFD81B60,
    0xFF8E24AA,
    0xFF5E35B1,
    0xFF3949AB,
    0xFF1E88E5,
    0xFF00897B,
    0xFF43A047,
    0xFF2E7D32,
    0xFFF4511E,
    0xFFFF8F00,
    0xFF6D4C41,
    0xFF757575,
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.category;
    if (c != null) {
      _nameController.text = c.name;
      _type = c.type;
      _icon = c.icon;
      _color = c.colorValue;
      _isIncomeCategory = c.type == CategoryType.income;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final repo = FinanceRepository.instance;
    await repo.saveCategory(
      Category(
        id: widget.category?.id ?? const Uuid().v4(),
        name: name,
        type: _type,
        icon: _icon,
        colorValue: _color,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.category != null ? 'Editar categoría' : 'Nueva categoría',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Es categoría de ingreso',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              value: _isIncomeCategory,
              onChanged:
                  (v) => setState(() {
                    _isIncomeCategory = v;
                    _type = v ? CategoryType.income : CategoryType.expense;
                  }),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: inputDecoration(
                'Nombre',
                'Ej. Cafetería',
                Icons.edit_outlined,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ícono',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: categoryIcons.length,
              itemBuilder: (context, index) {
                final name = categoryIcons.keys.elementAt(index);
                final selected = _icon == name;
                return InkWell(
                  onTap: () => setState(() => _icon = name),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? colorForCategory(_color).withValues(alpha: 0.15)
                              : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            selected
                                ? colorForCategory(_color)
                                : Colors.black12,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      iconForCategory(name),
                      color:
                          selected ? colorForCategory(_color) : Colors.black45,
                      size: 22,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Color',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final color in _colors)
                  InkWell(
                    onTap: () => setState(() => _color = color),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border:
                            _color == color
                                ? Border.all(color: Colors.black87, width: 3)
                                : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Guardar categoría',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
