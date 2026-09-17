import 'package:flutter/material.dart';

const seedColor = Color(0xFF1E88E5);
const backgroundColor = Color(0xFFF5F6FA);
const dangerColor = Color(0xFFE53935);
const successColor = Color(0xFF2E9E5B);

class AppColors {
  static const income = successColor;
  static const expense = dangerColor;
}

InputDecoration inputDecoration(String label, String hint, IconData icon) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: seedColor, width: 2),
      ),
    );
