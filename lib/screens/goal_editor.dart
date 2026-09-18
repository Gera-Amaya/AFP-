import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/finance_repository.dart';
import '../models/category.dart';
import '../models/savings_goal.dart';
import '../theme.dart';
import '../utils/format.dart';

class GoalEditorScreen extends StatefulWidget {
  final SavingsGoal? goal;
  final DateTime? planMonth;

  const GoalEditorScreen({super.key, this.goal, this.planMonth});

  @override
  State<GoalEditorScreen> createState() => _GoalEditorScreenState();
}

class _GoalEditorScreenState extends State<GoalEditorScreen> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _savedController = TextEditingController();
  final _contributionController = TextEditingController();
  String _categoryId = 'otros';
  DateTime? _deadline;

  bool get _isEditing => widget.goal != null;

  bool get _isCurrentPlanMonth {
    final now = DateTime.now();
    final month = widget.planMonth ?? now;
    return month.year == now.year && month.month == now.month;
  }

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    if (g != null) {
      _nameController.text = g.name;
      _targetController.text = g.targetAmount.toStringAsFixed(2);
      _savedController.text = g.savedAmount.toStringAsFixed(2);
      _categoryId = g.categoryId;
      _deadline = g.deadline;
      if (g.monthlyContribution != null) {
        _contributionController.text = g.monthlyContribution!.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _savedController.dispose();
    _contributionController.dispose();
    super.dispose();
  }

  String _resolveCategoryId(List<Category> categories) {
    if (categories.any((c) => c.id == _categoryId)) return _categoryId;
    return categories.isNotEmpty ? categories.first.id : '';
  }

  double? _parse(String text) =>
      double.tryParse(text.replaceAll(',', '.'));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final target = _parse(_targetController.text);
    if (name.isEmpty || target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un nombre y una meta válida.')),
      );
      return;
    }
    final repo = FinanceRepository.instance;
    final categoryId = _resolveCategoryId(
      repo.getCategoriesByType(CategoryType.expense),
    );
    final saved = _parse(_savedController.text);
    final contribution = _parse(_contributionController.text);
    await repo.saveSavingsGoal(
      SavingsGoal(
        id: widget.goal?.id ?? const Uuid().v4(),
        name: name,
        targetAmount: target,
        savedAmount: saved == null || saved < 0 ? 0 : saved.clamp(0, target),
        categoryId: categoryId,
        deadline: _deadline,
        monthlyContribution:
            contribution == null || contribution <= 0 ? null : contribution,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final repo = FinanceRepository.instance;
    final planMonth = widget.planMonth ?? DateTime.now();
    final available = repo.availableForSavings(planMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar meta' : 'Nueva meta de ahorro'),
      ),
      body: ValueListenableBuilder(
        valueListenable: repo.categoriesListenable,
        builder: (context, _, __) {
          final categories = repo.getCategoriesByType(CategoryType.expense);
          final categoryId = _resolveCategoryId(categories);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Define a qué estás ahorrando: una meta, el monto que llevas '
                  'y (opcional) una fecha límite para saber cuánto necesitas por mes.',
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
                    'Ej. Viaje, Emergencias, PS5',
                    Icons.savings_outlined,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _targetController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: inputDecoration(
                    'Monto de la meta',
                    'Ej. 12000',
                    Icons.flag_outlined,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _savedController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: inputDecoration(
                    'Ahorrado hasta ahora',
                    'Ej. 0',
                    Icons.account_balance_wallet_outlined,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: categoryId,
                  decoration: inputDecoration(
                    'Categoría para las aportaciones',
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
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: inputDecoration(
                      'Fecha límite (opcional)',
                      '',
                      Icons.event_outlined,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _deadline == null
                                ? 'Sin fecha límite'
                                : formatDateFull(_deadline!),
                          ),
                        ),
                        if (_deadline != null)
                          IconButton(
                            onPressed: () => setState(() => _deadline = null),
                            icon: const Icon(Icons.close, size: 20),
                            tooltip: 'Quitar fecha',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contributionController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: inputDecoration(
                    'Ahorro mensual previsto (opcional)',
                    'Ej. 1500',
                    Icons.trending_up_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: seedColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isCurrentPlanMonth
                        ? 'Tu "disponible para ahorro" es de '
                            '${formatMoney(available)}/mes según tu Plan.'
                        : 'Tu "disponible para ahorro" de '
                            '${monthName(planMonth)} es de '
                            '${formatMoney(available)}/mes según tu Plan.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: seedColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
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
                      _isEditing ? 'Guardar cambios' : 'Crear meta',
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