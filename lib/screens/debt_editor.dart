import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/finance_repository.dart';
import '../models/category.dart';
import '../models/debt.dart';
import '../theme.dart';
import '../utils/format.dart';

class DebtEditorScreen extends StatefulWidget {
  final Debt? debt;

  const DebtEditorScreen({super.key, this.debt});

  @override
  State<DebtEditorScreen> createState() => _DebtEditorScreenState();
}

class _DebtEditorScreenState extends State<DebtEditorScreen> {
  final _nameController = TextEditingController();
  final _totalController = TextEditingController();
  final _notesController = TextEditingController();
  String _categoryId = 'otros';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  bool get _isEditing => widget.debt != null;

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    if (d != null) {
      _nameController.text = d.name;
      _totalController.text = d.totalAmount.toStringAsFixed(2);
      _notesController.text = d.notes;
      _categoryId = d.categoryId;
      _dueDate = d.dueDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _totalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final total = double.tryParse(_totalController.text.replaceAll(',', '.'));
    if (name.isEmpty || total == null || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un nombre y un monto válido.')),
      );
      return;
    }
    final repo = FinanceRepository.instance;
    final existing = widget.debt;
    await repo.saveDebt(
      Debt(
        id: existing?.id ?? const Uuid().v4(),
        name: name,
        totalAmount: total,
        paidAmount: existing?.paidAmount ?? 0,
        categoryId: _categoryId,
        dueDate: _dueDate,
        notes: _notesController.text.trim(),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar deuda' : 'Nueva deuda')),
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
                  'Registra una deuda o compromiso por vencer y ve su progreso al abonar.',
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
                    'Ej. Tarjeta de crédito, Préstamo',
                    Icons.credit_card_outlined,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _totalController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: inputDecoration(
                    'Monto total',
                    'Ej. 8000',
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
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: inputDecoration(
                      'Fecha de vencimiento',
                      '',
                      Icons.event_outlined,
                    ),
                    child: Text(formatDateFull(_dueDate)),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  decoration: inputDecoration(
                    'Notas (opcional)',
                    'Ej. Tasa, pagos mensuales',
                    Icons.notes,
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
                      _isEditing ? 'Guardar cambios' : 'Agregar deuda',
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
