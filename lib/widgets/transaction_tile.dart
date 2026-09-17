import 'package:flutter/material.dart';

import '../data/finance_repository.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../theme.dart';
import '../utils/format.dart';

class CategoryAvatar extends StatelessWidget {
  final Category category;
  final double size;

  const CategoryAvatar({super.key, required this.category, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorForCategory(category.colorValue).withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(
        iconForCategory(category.icon),
        color: colorForCategory(category.colorValue),
        size: size * 0.55,
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final repo = FinanceRepository.instance;
    final category =
        transaction.categoryId.isNotEmpty &&
                repo.getCategories().any((c) => c.id == transaction.categoryId)
            ? repo.getCategory(transaction.categoryId)
            : null;
    final isIncome = transaction.type == CategoryType.income;
    final amountColor = isIncome ? AppColors.income : AppColors.expense;
    final sign = isIncome ? '+' : '-';

    Widget leading =
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
            );

    return ListTile(
      leading: leading,
      title: Text(
        transaction.description.isNotEmpty
            ? transaction.description
            : (category?.name ?? 'Sin categoría'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${formatDateFull(transaction.date)} · ${formatTime(transaction.date)}'
        '${transaction.tags.isNotEmpty ? ' · #${transaction.tags.join(' #')}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Text(
        '$sign${formatMoney(transaction.amount)}',
        style: TextStyle(
          color: amountColor,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
