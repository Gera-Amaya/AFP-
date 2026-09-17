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
  DateTime _startDate = DateTime.now().add(const Duration(days: 30));
  PaymentFrequency _frequency = PaymentFrequency.monthly;
  int _numberOfPayments = 1;

  bool get _isEditing => widget.debt != null;

  bool get _scheduled => _frequency != PaymentFrequency.oneTime;

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    if (d != null) {
      _nameController.text = d.name;
      _totalController.text = d.totalAmount.toStringAsFixed(2);
      _notesController.text = d.notes;
      _categoryId = d.categoryId;
      _startDate = d.startDate;
      _frequency = d.frequency;
      _numberOfPayments = d.numberOfPayments;
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
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
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
    if (_scheduled && _numberOfPayments < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indica el número de pagos.')),
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
        startDate: _startDate,
        frequency: _frequency,
        numberOfPayments: _scheduled ? _numberOfPayments : 1,
        notes: _notesController.text.trim(),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  String _dateLabel() => _scheduled ? 'Fecha del primer pago' : 'Fecha de pago';

  String _previewText(double total) {
    if (!_scheduled) {
      return 'Pago único de ${formatMoney(total)} el ${formatDateFull(_startDate)}';
    }
    final schedule = computeInstallments(
      total: total,
      frequency: _frequency,
      start: _startDate,
      numberOfPayments: _numberOfPayments,
    );
    if (schedule.isEmpty) return '';
    final last = schedule.last.date;
    return '$_numberOfPayments pagos de ${formatMoney(schedule.first.amount)} '
        '${_frequency.shortLabel} · hasta el ${formatDateFull(last)}';
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
          final total = double.tryParse(
            _totalController.text.replaceAll(',', '.'),
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registra una deuda y planifica sus pagos por semana, '
                  'quincena o mes. También puedes dejarla como pago único.',
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
                  onChanged: (_) => setState(() {}),
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
                DropdownButtonFormField<PaymentFrequency>(
                  value: _frequency,
                  decoration: inputDecoration(
                    'Frecuencia de pago',
                    '',
                    Icons.schedule_outlined,
                  ),
                  items: [
                    for (final f in PaymentFrequency.values)
                      DropdownMenuItem(value: f, child: Text(f.label)),
                  ],
                  onChanged: (v) => setState(() => _frequency = v!),
                ),
                if (_scheduled) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Número de pagos',
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
                                _numberOfPayments > 1
                                    ? () => setState(() => _numberOfPayments--)
                                    : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Expanded(
                            child: Text(
                              '$_numberOfPayments',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed:
                                _numberOfPayments < 48
                                    ? () => setState(() => _numberOfPayments++)
                                    : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: inputDecoration(
                      _dateLabel(),
                      '',
                      Icons.event_outlined,
                    ),
                    child: Text(formatDateFull(_startDate)),
                  ),
                ),
                if (total != null && total > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _previewText(total),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  decoration: inputDecoration(
                    'Notas (opcional)',
                    'Ej. Tasa, tienda',
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
