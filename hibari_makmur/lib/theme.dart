import 'package:flutter/material.dart';

class AppColors {
  static const sidebar = Color(0xFF0E3B2C);
  static const sidebarActive = Color(0xFF3E8E5E);
  static const sidebarText = Color(0xFFE6EFEA);
  static const sidebarSection = Color(0xFF9DB8AA);
  static const bg = Color(0xFFF2F5F8);
  static const green = Color(0xFF22A05B);
  static const blue = Color(0xFF2F80ED);
  static const orange = Color(0xFFF2994A);
  static const red = Color(0xFFE53935);
  static const yellow = Color(0xFFF2C94C);
  static const gold = Color(0xFFC9A45C);
  static const text = Color(0xFF1F2937);
  static const muted = Color(0xFF6B7280);
  static const border = Color(0xFFE5E7EB);
  static const link = Color(0xFF2563EB);
  static const brand = Color(0xFF156143);
  static const brandGold = Color(0xFFEBB01C);
  static const brandNavy = Color(0xFF0F172A);

  static const kategori = <String, Color>{
    'Besi & Baja': Color(0xFF2F6FED),
    'Cat': Color(0xFFF2C94C),
    'Perlengkapan Bangunan': Color(0xFFF2667A),
    'Alat Pertukangan': Color(0xFFD9B95B),
    'Kunci & Engsel': Color(0xFFF7A93B),
    'Lainnya': Color(0xFFA3B4D1),
  };
}

ThemeData buildTheme() {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.border),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: AppColors.green,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: border,
      enabledBorder: border,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(Color(0xFFF3F4F6)),
      headingTextStyle: TextStyle(
          fontWeight: FontWeight.w600, color: AppColors.text, fontSize: 13),
      dataTextStyle: TextStyle(fontSize: 13, color: AppColors.text),
      headingRowHeight: 40,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 48,
      horizontalMargin: 12,
      columnSpacing: 24,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );
}
