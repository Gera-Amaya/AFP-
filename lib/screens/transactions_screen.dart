import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/finance_repository.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  DateTime _month = DateTime.now();
  int? _typeFilter; // null = todos, 0 = gasto, 1 = ingreso

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final repo = FinanceRepository.instance;

    return ValueListenableBuilder(
      valueListenable: repo.categoriesListenable,
      builder: (context, _, __) {
        return ValueListenableBuilder(
          valueListenable: repo.transactionsListenable,
          builder: (context, _, __) {
            final all =
                repo.getTransactions()
                  ..sort((a, b) => b.date.compareTo(a.date));
            final filtered =
                all.where((t) {
                  final inMonth =
                      t.date.year == _month.year &&
                      t.date.month == _month.month;
                  if (!inMonth) return false;
                  if (_typeFilter == null) return true;
                  return t.type ==
                      (_typeFilter == 0
                          ? CategoryType.expense
                          : CategoryType.income);
                }).toList();

            return Scaffold(
              appBar: AppBar(title: const Text('Movimientos')),
              body: Column(
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => _shiftMonth(-1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Column(
                          children: [
                            Text(
                              DateFormat(
                                'MMMM yyyy',
                                'es_MX',
                              ).format(_month).toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              '${formatMoney(filtered.fold<double>(0, (s, t) => s + (t.type == CategoryType.income ? t.amount : -t.amount)))} del mes',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed:
                              _month.year == DateTime.now().year &&
                                      _month.month == DateTime.now().month
                                  ? null
                                  : () => _shiftMonth(1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Todos',
                          selected: _typeFilter == null,
                          onTap: () => setState(() => _typeFilter = null),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Gastos',
                          selected: _typeFilter == 0,
                          onTap: () => setState(() => _typeFilter = 0),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Ingresos',
                          selected: _typeFilter == 1,
                          onTap: () => setState(() => _typeFilter = 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child:
                        filtered.isEmpty
                            ? const Center(
                              child: Text(
                                'Sin movimientos en este mes.',
                                style: TextStyle(color: Colors.black45),
                              ),
                            )
                            : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 90),
                              itemCount: filtered.length,
                              separatorBuilder:
                                  (_, __) => const Divider(
                                    height: 1,
                                    indent: 72,
                                    endIndent: 16,
                                    color: Colors.black12,
                                  ),
                              itemBuilder: (context, index) {
                                final t = filtered[index];
                                return TransactionTile(
                                  transaction: t,
                                  onTap: () => _openEdit(context, t),
                                  onLongPress: () => _confirmDelete(context, t),
                                );
                              },
                            ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openEdit(BuildContext context, Transaction t) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddTransactionScreen(transaction: t)),
    );
  }

  void _confirmDelete(BuildContext context, Transaction t) {
    final repo = FinanceRepository.instance;
    showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Eliminar movimiento'),
            content: const Text('¿Seguro que deseas eliminar este movimiento?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancelar'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: dangerColor),
                onPressed: () async {
                  await repo.deleteTransaction(t.id);
                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                },
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
