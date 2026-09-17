import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/finance_repository.dart';
import '../models/category.dart';
import '../models/debt.dart';
import '../models/plan_config.dart';
import '../models/planned_expense.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/transaction_tile.dart';
import 'debt_editor.dart';
import 'planned_expense_editor.dart';

class PlanTab extends StatefulWidget {
  const PlanTab({super.key});

  @override
  State<PlanTab> createState() => _PlanTabState();
}

class _PlanTabState extends State<PlanTab> {
  DateTime _month = DateTime.now();
  Listenable? _listenable;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listenable != null) {
      _listenable!.removeListener(_onChanged);
    }
    final repo = FinanceRepository.instance;
    final listenable = Listenable.merge([
      repo.categoriesListenable,
      repo.plannedExpensesListenable,
      repo.debtsListenable,
      repo.planConfigListenable,
    ]);
    _listenable = listenable;
    _listenable!.addListener(_onChanged);
  }

  @override
  void dispose() {
    _listenable?.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repo = FinanceRepository.instance;
    final expenses = repo.getPlannedExpenses();
    final debts = repo.getDebts();
    final config = repo.getPlanConfig();
    final currentKey = currentMonthKey(_month);

    final plannedTotal = repo.plannedExpensesTotal();
    final debtsDue = repo.debtsDueTotal(_month);
    final available = repo.availableForSavings(_month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan'),
        actions: [
          IconButton(
            onPressed: () => _openConfig(context, config),
            icon: const Icon(Icons.tune),
            tooltip: 'Ajustar ingreso y meta de ahorro',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MonthSelector(
            month: _month,
            onPrev:
                () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
            onNext:
                () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
          ),
          const SizedBox(height: 12),
          _SavingsCard(
            income: config.monthlyIncome,
            plannedTotal: plannedTotal,
            debtsDue: debtsDue,
            available: available,
            goal: config.savingsGoal,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Compromisos del mes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openExpenseEditor(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
              ),
            ],
          ),
          if (expenses.isEmpty)
            const _HintCard(
              icon: Icons.event_note_outlined,
              text: 'Aún no hay compromisos. Agrega tus gastos fijos del mes.',
            )
          else
            Card(
              child: Column(
                children: [
                  for (final e in expenses)
                    _PlannedExpenseTile(
                      expense: e,
                      monthKey: currentKey,
                      isCurrentMonth: _isCurrentMonth,
                      onPaid: () => _markPaid(context, e),
                      onEdit: () => _openExpenseEditor(context, e),
                      onDelete: () => _deleteExpense(context, e),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                'Deudas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openDebtEditor(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
              ),
            ],
          ),
          if (debts.isEmpty)
            const _HintCard(
              icon: Icons.credit_card_outlined,
              text: 'Aún no hay deudas registradas.',
            )
          else
            for (final d in debts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DebtCard(
                  debt: d,
                  month: _month,
                  onPay: () => _pay(context, d),
                  onPayInstallment: (inst) => _payInstallment(context, d, inst),
                  onEdit: () => _openDebtEditor(context, d),
                  onDelete: () => _deleteDebt(context, d),
                ),
              ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return now.year == _month.year && now.month == _month.month;
  }

  void _openExpenseEditor(BuildContext context, [PlannedExpense? e]) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlannedExpenseEditorScreen(expense: e)),
    );
  }

  void _openDebtEditor(BuildContext context, [Debt? d]) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DebtEditorScreen(debt: d)));
  }

  void _markPaid(BuildContext context, PlannedExpense e) {
    FinanceRepository.instance.markPlannedExpensePaid(e);
  }

  void _deleteExpense(BuildContext context, PlannedExpense e) {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Eliminar compromiso'),
            content: Text('¿Eliminar "${e.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: dangerColor),
                onPressed: () async {
                  await FinanceRepository.instance.deletePlannedExpense(e.id);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }

  void _deleteDebt(BuildContext context, Debt d) {
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Eliminar deuda'),
            content: Text('¿Eliminar "${d.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: dangerColor),
                onPressed: () async {
                  await FinanceRepository.instance.deleteDebt(d.id);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }

  void _pay(BuildContext context, Debt d) {
    final controller = TextEditingController(
      text: d.remaining.toStringAsFixed(2),
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Abonar a "${d.name}"'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Monto del abono',
            prefixText: r'$ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(
                controller.text.replaceAll(',', '.'),
              );
              if (amount == null || amount <= 0) return;
              final effective = amount > d.remaining ? d.remaining : amount;
              await FinanceRepository.instance.payDebt(d, effective);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Abonar'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _payInstallment(BuildContext context, Debt d, DebtInstallment inst) {
    final effective = inst.amount > d.remaining ? d.remaining : inst.amount;
    if (effective <= 0) return;
    FinanceRepository.instance.payDebt(
      d,
      effective,
      description: '${d.name} (cuota ${formatDateShort(inst.date)})',
    );
  }

  void _openConfig(BuildContext context, PlanConfig config) {
    final incomeController = TextEditingController(
      text: config.monthlyIncome == 0
          ? ''
          : config.monthlyIncome.toStringAsFixed(2),
    );
    final goalController = TextEditingController(
      text: config.savingsGoal == 0 ? '' : config.savingsGoal.toStringAsFixed(2),
    );
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Presupuesto y ahorro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: incomeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Ingreso mensual planeado (sueldo)',
                prefixText: r'$ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: goalController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Meta de ahorro mensual',
                prefixText: r'$ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              await FinanceRepository.instance.savePlanConfig(
                PlanConfig(
                  monthlyIncome:
                      double.tryParse(
                        incomeController.text.replaceAll(',', '.'),
                      ) ??
                      0,
                  savingsGoal:
                      double.tryParse(
                        goalController.text.replaceAll(',', '.'),
                      ) ??
                      0,
                ),
              );
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).whenComplete(() {
      incomeController.dispose();
      goalController.dispose();
    });
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthSelector({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrent = now.year == month.year && now.month == month.month;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
            Text(
              DateFormat('MMMM yyyy', 'es_MX').format(month).toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            IconButton(
              onPressed: isCurrent ? null : onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingsCard extends StatelessWidget {
  final double income;
  final double plannedTotal;
  final double debtsDue;
  final double available;
  final double goal;

  const _SavingsCard({
    required this.income,
    required this.plannedTotal,
    required this.debtsDue,
    required this.available,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final onTrack = goal <= 0 || available >= goal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ahorro planeado',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            label: 'Ingreso planeado',
            amount: income,
            icon: Icons.payments_outlined,
            color: AppColors.income,
          ),
          _SummaryRow(
            label: 'Compromisos mensuales',
            amount: plannedTotal,
            icon: Icons.event_note_outlined,
            color: AppColors.expense,
          ),
          _SummaryRow(
            label: 'Deudas por vencer',
            amount: debtsDue,
            icon: Icons.credit_card_outlined,
            color: AppColors.expense,
          ),
          const Divider(height: 20),
          Row(
            children: [
              const Icon(Icons.savings_outlined, color: seedColor, size: 20),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Disponible para ahorro',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                formatMoney(available),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: available >= 0 ? AppColors.income : dangerColor,
                ),
              ),
            ],
          ),
          if (goal > 0) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: goal <= 0 ? 0 : (available / goal).clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: Colors.black12,
                      color: onTrack ? AppColors.income : dangerColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Meta: ${formatMoney(goal)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              onTrack
                  ? 'Estás cumpliendo tu meta de ahorro.'
                  : 'Faltan ${formatMoney(goal - available)} para tu meta.',
              style: TextStyle(
                fontSize: 12,
                color: onTrack ? AppColors.income : dangerColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (income == 0) ...[
            const SizedBox(height: 10),
            Text(
              'Configura tu ingreso mensual para ver cuánto puedes ahorrar.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black45.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _SummaryRow({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            formatMoney(amount),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PlannedExpenseTile extends StatelessWidget {
  final PlannedExpense expense;
  final String monthKey;
  final bool isCurrentMonth;
  final VoidCallback onPaid;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlannedExpenseTile({
    required this.expense,
    required this.monthKey,
    required this.isCurrentMonth,
    required this.onPaid,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final repo = FinanceRepository.instance;
    final category = repo.getCategory(expense.categoryId);
    final paid = expense.lastPaidKey == monthKey;

    return ListTile(
      leading:
          category != null
              ? CategoryAvatar(category: category)
              : const CategoryAvatar(
                category: Category(
                  id: '',
                  name: '',
                  type: CategoryType.expense,
                  icon: 'category',
                  colorValue: 0xFF757575,
                ),
              ),
      title: Text(
        expense.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Día ${expense.dayOfMonth} · ${category?.name ?? ''}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (paid)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.check_circle,
                color: AppColors.income,
                size: 22,
              ),
            )
          else if (isCurrentMonth)
            TextButton(onPressed: onPaid, child: const Text('Pagar')),
          Text(
            formatMoney(expense.amount),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder:
                (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final Debt debt;
  final DateTime month;
  final VoidCallback onPay;
  final ValueChanged<DebtInstallment> onPayInstallment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DebtCard({
    required this.debt,
    required this.month,
    required this.onPay,
    required this.onPayInstallment,
    required this.onEdit,
    required this.onDelete,
  });

  String get _scheduleInfo {
    if (debt.installmentCount <= 1) {
      return 'Pago único el ${formatDateFull(debt.startDate)}';
    }
    final last = debt.installments.last.date;
    return '${debt.installmentCount} pagos de '
        '${formatMoney(debt.installments.first.amount)} '
        '${debt.frequency.shortLabel} · hasta ${formatDateFull(last)}';
  }

  @override
  Widget build(BuildContext context) {
    final repo = FinanceRepository.instance;
    final category = repo.getCategory(debt.categoryId);
    final pending = repo.pendingInstallmentsForMonth(debt, month);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debt.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _scheduleInfo +
                            (category != null ? ' · ${category.name}' : ''),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                      ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: debt.progress,
                      minHeight: 7,
                      backgroundColor: Colors.black12,
                      color: debt.isPaidOff ? AppColors.income : seedColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  debt.isPaidOff
                      ? 'Liquidada'
                      : '${formatMoney(debt.remaining)} restan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: debt.isPaidOff ? AppColors.income : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pagado ${formatMoney(debt.paidAmount)} de ${formatMoney(debt.totalAmount)}',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
            if (debt.isPaidOff) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.income,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Deuda liquidada',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.income,
                    ),
                  ),
                ],
              ),
            ] else if (pending.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Pagos planeados de este mes',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final inst in pending) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        inst.date.isBefore(DateTime(month.year, month.month))
                            ? Icons.warning_amber_outlined
                            : Icons.event_outlined,
                        size: 16,
                        color:
                            inst.date.isBefore(
                                  DateTime(month.year, month.month),
                                )
                                ? Colors.orange
                                : Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${formatDateShort(inst.date)}'
                          '${inst.date.isBefore(DateTime(month.year, month.month)) ? ' (vencida)' : ''}'
                          ' · ${formatMoney(inst.amount)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => onPayInstallment(inst),
                        child: const Text('Pagar cuota'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ] else
              ...[],
            if (!debt.isPaidOff) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: onPay,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Abonar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HintCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black26, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.black54)),
          ),
        ],
      ),
    );
  }
}
