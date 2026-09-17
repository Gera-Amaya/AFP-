import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/finance_repository.dart';
import '../models/category.dart';
import '../models/planned_expense.dart';
import '../theme.dart';

class PlannedExpenseEditorScreen extends StatefulWidget {
  final PlannedExpense? expense;

  const PlannedExpenseEditorScreen({super.key, this.expense});

  @override
  State<PlannedExpenseEditorScreen> createState() =>
      _PlannedExpenseEditorScreenState();
}

class _PlannedExpenseEditorScreenState
    extends State<PlannedExpenseEditorScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String _categoryId = 'comida';
  int _dayOfMonth = DateTime.now().day;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    if (e != null) {
      _nameController.text = e.name;
      _amountController.text = e.amount.toStringAsFixed(2);
      _categoryId = e.categoryId;
      _dayOfMonth = e.dayOfMonth;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (name.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un nombre y un monto válido.')),
      );
      return;
    }
    final repo = FinanceRepository.instance;
    await repo.savePlannedExpense(
      PlannedExpense(
        id: widget.expense?.id ?? const Uuid().v4(),
        name: name,
        amount: amount,
        categoryId: _categoryId,
        dayOfMonth: _dayOfMonth,
        lastPaidKey: widget.expense?.lastPaidKey,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar compromiso' : 'Nuevo compromiso'),
      ),
      body: ValueListenableBuilder(
        valueListenable: FinanceRepository.instance.categoriesListenable,
        builder: (context, _, __) {
          final categories = FinanceRepository.instance.getCategoriesByType(
            CategoryType.expense,
          );
          if (!categories.any((c) => c.id == _categoryId) &&
              categories.isNotEmpty) {
            _categoryId = categories.first.id;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Un compromiso es un gasto fijo cada mes (renta, teléfono, suscripciones…).',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  decoration: inputDecoration(
                    'Nombre',
                    'Ej. Renta, Teléfono, Netflix',
                    Icons.event_note_outlined,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: inputDecoration(
                    'Monto mensual',
                    'Ej. 4500',
                    Icons.attach_money,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _categoryId,
                  decoration: inputDecoration(
                    'Categoría',
                    '',
                    Icons.category_outlined,
                  ),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v!),
                ),
                const SizedBox(height: 16),
                Text(
                  'Día del mes en que se paga',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed:
                              _dayOfMonth > 1
                                  ? () => setState(() => _dayOfMonth--)
                                  : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Expanded(
                          child: Text(
                            'Día $_dayOfMonth',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed:
                              _dayOfMonth < 31
                                  ? () => setState(() => _dayOfMonth++)
                                  : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
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
                    child: Text(
                      _isEditing ? 'Guardar cambios' : 'Agregar compromiso',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
