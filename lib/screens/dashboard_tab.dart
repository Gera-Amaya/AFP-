import 'package:flutter/material.dart';

import '../data/finance_repository.dart';
import '../models/transaction.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/transaction_tile.dart';
import 'add_transaction_screen.dart';

class DashboardTab extends StatelessWidget {
  final VoidCallback onShowAll;

  const DashboardTab({super.key, required this.onShowAll});

  @override
  Widget build(BuildContext context) {
    final repo = FinanceRepository.instance;

    return ValueListenableBuilder(
      valueListenable: repo.categoriesListenable,
      builder: (context, _, __) {
        return ValueListenableBuilder(
          valueListenable: repo.transactionsListenable,
          builder: (context, _, __) {
            final now = DateTime.now();
            final balance = repo.getBalance();
            final income = repo.getMonthIncome(now);
            final expense = repo.getMonthExpense(now);

            final transactions =
                repo.getTransactions()
                  ..sort((a, b) => b.date.compareTo(a.date));
            final recent =
                transactions.length > 5
                    ? transactions.sublist(0, 5)
                    : transactions;

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.white,
                  title: const Text('Finanzas Personales'),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        monthName(now),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList.list(
                    children: [
                      _BalanceSheet(
                        balance: balance,
                        income: income,
                        expense: expense,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text(
                            'Movimientos recientes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: onShowAll,
                            child: const Text('Ver todos'),
                          ),
                        ],
                      ),
                      if (transactions.isEmpty)
                        const _EmptyState()
                      else
                        Card(
                          child: Column(
                            children: [
                              for (final t in recent)
                                TransactionTile(
                                  transaction: t,
                                  onTap: () => _openEdit(context, t),
                                  onLongPress: () => _confirmDelete(context, t),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 72),
                    ],
                  ),
                ),
              ],
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

class _BalanceSheet extends StatelessWidget {
  final double balance;
  final double income;
  final double expense;

  const _BalanceSheet({
    required this.balance,
    required this.income,
    required this.expense,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: seedColor.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Balance total',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                formatMoney(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Ingresos del mes',
                amount: income,
                color: AppColors.income,
                icon: Icons.arrow_drop_up,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'Gastos del mes',
                amount: expense,
                color: AppColors.expense,
                icon: Icons.arrow_drop_down,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatMoney(amount),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: Colors.black26,
          ),
          SizedBox(height: 12),
          Text(
            'Aún no tienes movimientos.\n¡Agrega tu primer ingreso o gasto!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}
