import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/finance_repository.dart';
import '../models/category.dart';
import '../theme.dart';
import '../utils/format.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _month = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final repo = FinanceRepository.instance;

    return ValueListenableBuilder(
      valueListenable: repo.categoriesListenable,
      builder: (context, _, __) {
        return ValueListenableBuilder(
          valueListenable: repo.transactionsListenable,
          builder: (context, _, __) {
            return Scaffold(
              appBar: AppBar(title: const Text('Reportes')),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _MonthSelector(
                    month: _month,
                    onPrev:
                        () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month - 1),
                        ),
                    onNext:
                        () => setState(
                          () =>
                              _month = DateTime(_month.year, _month.month + 1),
                        ),
                  ),
                  const SizedBox(height: 16),
                  _ExpensePieCard(month: _month),
                  const SizedBox(height: 16),
                  _TrendCard(),
                ],
              ),
            );
          },
        );
      },
    );
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
    final isCurrentMonth =
        month.year == DateTime.now().year &&
        month.month == DateTime.now().month;
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
              onPressed: isCurrentMonth ? null : onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpensePieCard extends StatelessWidget {
  final DateTime month;
  const _ExpensePieCard({required this.month});

  @override
  Widget build(BuildContext context) {
    final repo = FinanceRepository.instance;
    final expenses =
        repo
            .getTransactionsBetween(
              DateTime(month.year, month.month),
              DateTime(
                month.year,
                month.month + 1,
              ).subtract(const Duration(days: 1)),
            )
            .where((t) => t.type == CategoryType.expense)
            .toList();

    final categoryTotals = <String, double>{};
    for (final t in expenses) {
      categoryTotals[t.categoryId] =
          (categoryTotals[t.categoryId] ?? 0) + t.amount;
    }

    final total = categoryTotals.values.fold<double>(0, (a, b) => a + b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gastos por categoría',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${formatMoney(total)} en total',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.expense,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            if (categoryTotals.isEmpty)
              const SizedBox(
                height: 160,
                child: Center(
                  child: Text(
                    'No hay gastos este mes',
                    style: TextStyle(color: Colors.black45),
                  ),
                ),
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 45,
                        sections: [
                          for (final entry in categoryTotals.entries)
                            _pieSection(entry.key, entry.value, total),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        for (final entry in categoryTotals.entries)
                          _LegendRow(category: entry.key, amount: entry.value),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _pieSection(
    String categoryId,
    double value,
    double total,
  ) {
    final categories = FinanceRepository.instance.getCategories();
    Category? category;
    for (final c in categories) {
      if (c.id == categoryId) {
        category = c;
        break;
      }
    }
    final percent = total == 0 ? 0.0 : (value / total * 100);
    return PieChartSectionData(
      value: value,
      title: '${percent.toStringAsFixed(0)}%',
      radius: 40,
      color:
          category != null
              ? colorForCategory(category.colorValue)
              : const Color(0xFF757575),
      titleStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final String category;
  final double amount;

  const _LegendRow({required this.category, required this.amount});

  @override
  Widget build(BuildContext context) {
    final repo = FinanceRepository.instance;
    final c =
        repo.getCategory(category) ??
        Category(
          id: category,
          name: 'Sin categoría',
          type: CategoryType.expense,
          icon: 'category',
          colorValue: 0xFF757575,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: colorForCategory(c.colorValue),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            formatMoney(amount),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatefulWidget {
  const _TrendCard();

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  int _months = 6;

  @override
  Widget build(BuildContext context) {
    final repo = FinanceRepository.instance;
    final now = DateTime.now();

    final incomes = <double>[];
    final expenses = <double>[];
    final labels = <String>[];

    for (int i = _months - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      labels.add(DateFormat.MMM('es_MX').format(month));
      incomes.add(repo.getMonthIncome(month));
      expenses.add(repo.getMonthExpense(month));
    }

    final maxValue = [
      ...incomes,
      ...expenses,
    ].fold<double>(0, (a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Ingresos vs gastos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                SegmentedButton<int>(
                  segments: [
                    ButtonSegment(value: 3, label: Text('3M')),
                    ButtonSegment(value: 6, label: Text('6M')),
                    ButtonSegment(value: 12, label: Text('12M')),
                  ],
                  selected: {_months},
                  onSelectionChanged: (s) => setState(() => _months = s.first),
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          formatMoney(rod.toY),
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              labels[index],
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (int i = 0; i < labels.length; i++)
                      BarChartGroupData(
                        x: i,
                        barsSpace: 3,
                        barRods: [
                          BarChartRodData(
                            toY: incomes[i],
                            color: AppColors.income,
                            width: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          BarChartRodData(
                            toY: expenses[i],
                            color: AppColors.expense,
                            width: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                  ],
                  minY: 0,
                  maxY: maxValue == 0 ? 1 : maxValue * 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _LegendDot(label: 'Ingresos', color: AppColors.income),
                SizedBox(width: 16),
                _LegendDot(label: 'Gastos', color: AppColors.expense),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
