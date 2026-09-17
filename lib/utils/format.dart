import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';

String formatMoney(double value) =>
    NumberFormat.currency(locale: 'es_MX', symbol: r'$').format(value);

String monthName(DateTime date) =>
    DateFormat.MMMM('es_MX').format(date).toUpperCase();

String formatDateFull(DateTime date) =>
    DateFormat('d MMM yyyy', 'es_MX').format(date);

String formatDateShort(DateTime date) =>
    DateFormat('d MMM', 'es_MX').format(date);

String formatTime(DateTime date) => DateFormat('HH:mm', 'es_MX').format(date);

String currentMonthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

const categoryIcons = {
  'payments': Icons.payments_outlined,
  'savings': Icons.savings_outlined,
  'restaurant': Icons.restaurant_outlined,
  'shopping_cart': Icons.shopping_cart_outlined,
  'home': Icons.home_outlined,
  'bolt': Icons.bolt_outlined,
  'directions_bus': Icons.directions_bus_outlined,
  'local_hospital': Icons.local_hospital_outlined,
  'movie': Icons.movie_outlined,
  'shopping_bag': Icons.shopping_bag_outlined,
  'category': Icons.category_outlined,
  'work': Icons.work_outline,
  'school': Icons.school_outlined,
  'pets': Icons.pets_outlined,
  'sports': Icons.sports_soccer_outlined,
  'flight': Icons.flight_outlined,
  'phone': Icons.phone_android_outlined,
  'fitness': Icons.fitness_center_outlined,
  'favorite': Icons.favorite_outline,
  'card_giftcard': Icons.card_giftcard_outlined,
  'attach_money': Icons.attach_money_outlined,
  'wallet': Icons.wallet_outlined,
};

IconData iconForCategory(String iconName) =>
    categoryIcons[iconName] ?? Icons.category_outlined;

Color colorForCategory(int colorValue) => Color(colorValue);

String typeLabel(CategoryType type) =>
    type == CategoryType.income ? 'Ingreso' : 'Gasto';
