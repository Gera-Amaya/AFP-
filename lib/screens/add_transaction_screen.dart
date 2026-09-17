import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/finance_repository.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../theme.dart';
import '../utils/format.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();
  CategoryType _type = CategoryType.expense;
  String _categoryId = 'comida';
  DateTime _date = DateTime.now();
  final List<String> _tags = [];
  String? _error;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    if (t != null) {
      _type = t.type;
      _categoryId = t.categoryId;
      _amountController.text = t.amount.toStringAsFixed(2);
      _descriptionController.text = t.description;
      _date = t.date;
      _tags.addAll(t.tags);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _addTag() {
    final text = _tagController.text.trim().replaceAll(RegExp(r'^#+'), '');
    if (text.isNotEmpty && !_tags.contains(text)) {
      setState(() => _tags.add(text));
    }
    _tagController.clear();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Ingresa un monto válido mayor a 0.');
      return;
    }
    final repo = FinanceRepository.instance;
    final existing = widget.transaction;
    final transaction = Transaction(
      id: existing?.id ?? const Uuid().v4(),
      type: _type,
      amount: amount,
      categoryId: _categoryId,
      tags: List.of(_tags),
      description: _descriptionController.text.trim(),
      date: _date,
    );
    await repo.saveTransaction(transaction);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar movimiento' : 'Nuevo movimiento'),
      ),
      body: ValueListenableBuilder(
        valueListenable: FinanceRepository.instance.categoriesListenable,
        builder: (context, _, __) {
          final repo = FinanceRepository.instance;
          final categories = repo.getCategoriesByType(_type);

          if (!categories.any((c) => c.id == _categoryId)) {
            _categoryId = categories.isNotEmpty ? categories.first.id : '';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TypeSelector(
                  value: _type,
                  onChanged: (t) => setState(() => _type = t),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: !_isEditing,
                  decoration: inputDecoration(
                    'Monto',
                    'Ej. 350.50',
                    Icons.attach_money,
                  ),
                ),
                const SizedBox(height: 16),
                Text('Categoría', style: _labelStyle),
                const SizedBox(height: 8),
                if (categories.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No hay categorías para este tipo. Crea una en la pestaña Categorías.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 130,
                    child: _CategoryGrid(
                      categories: categories,
                      selectedId: _categoryId,
                      onSelect: (id) => setState(() => _categoryId = id),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: inputDecoration(
                    'Descripción (opcional)',
                    'Ej. Compra semanal',
                    Icons.notes,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: inputDecoration(
                      'Fecha',
                      '',
                      Icons.calendar_month_outlined,
                    ),
                    child: Text(formatDateFull(_date)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Etiquetas', style: _labelStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in _tags)
                      Chip(
                        label: Text('#$tag'),
                        onDeleted: () => setState(() => _tags.remove(tag)),
                        backgroundColor: seedColor.withValues(alpha: 0.1),
                        deleteIconColor: seedColor,
                      ),
                    if (_tags.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Sin etiquetas',
                          style: TextStyle(color: Colors.black45),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        onSubmitted: (_) => _addTag(),
                        decoration: inputDecoration(
                          'Agregar etiqueta',
                          'Ej. viaje',
                          Icons.label_outline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _addTag,
                      icon: const Icon(Icons.add),
                      tooltip: 'Agregar etiqueta',
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: dangerColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: categories.isEmpty ? null : _save,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _isEditing ? 'Guardar cambios' : 'Guardar movimiento',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  TextStyle get _labelStyle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: Colors.black87,
  );
}

class _TypeSelector extends StatelessWidget {
  final CategoryType value;
  final ValueChanged<CategoryType> onChanged;

  const _TypeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CategoryType>(
      segments: const [
        ButtonSegment(
          value: CategoryType.expense,
          label: Text('Gasto'),
          icon: Icon(Icons.arrow_downward),
        ),
        ButtonSegment(
          value: CategoryType.income,
          label: Text('Ingreso'),
          icon: Icon(Icons.arrow_upward),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: seedColor.withValues(alpha: 0.15),
        selectedForegroundColor: seedColor,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<Category> categories;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _CategoryGrid({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final c = categories[index];
        final selected = c.id == selectedId;
        return InkWell(
          onTap: () => onSelect(c.id),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 92,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color:
                  selected
                      ? colorForCategory(c.colorValue).withValues(alpha: 0.2)
                      : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    selected ? colorForCategory(c.colorValue) : Colors.black12,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  iconForCategory(c.icon),
                  color: colorForCategory(c.colorValue),
                  size: 26,
                ),
                const SizedBox(height: 8),
                Text(
                  c.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
