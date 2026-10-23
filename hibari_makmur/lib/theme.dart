import 'package:flutter/material.dart';

class AppColors {
  static const sidebar = Color(0xFF0B3325);
  static const sidebarDark = Color(0xFF072118);
  static const sidebarActive = Color(0x1FFFFFFF);
  static const sidebarText = Color(0xFFE6EFEA);
  static const sidebarSection = Color(0xFF7FA493);
  static const bg = Color(0xFFF4F6F5);
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
  static const brandSoft = Color(0xFFE7F3EC);
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
  OutlineInputBorder garis(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: w),
      );
  final bentuk = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brand,
      primary: AppColors.brand,
      secondary: AppColors.brandGold,
      surface: Colors.white,
      error: AppColors.red,
    ),
    scaffoldBackgroundColor: AppColors.bg,
    dividerColor: AppColors.border,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: garis(AppColors.border),
      enabledBorder: garis(AppColors.border),
      focusedBorder: garis(AppColors.brand, 1.6),
      errorBorder: garis(AppColors.red),
      focusedErrorBorder: garis(AppColors.red, 1.6),
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      prefixIconColor: const Color(0xFF9CA3AF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: const WidgetStatePropertyAll(Color(0xFFF7F9F8)),
      dataRowColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.hovered) ? const Color(0xFFF3F8F5) : null),
      headingTextStyle: const TextStyle(
          fontWeight: FontWeight.w600, color: AppColors.muted, fontSize: 12.5, letterSpacing: 0.2),
      dataTextStyle: const TextStyle(fontSize: 13, color: AppColors.text),
      dividerThickness: 0.6,
      headingRowHeight: 44,
      dataRowMinHeight: 44,
      dataRowMaxHeight: 58,
      horizontalMargin: 14,
      columnSpacing: 24,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 6,
      shadowColor: const Color(0x33000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.white),
        surfaceTintColor: WidgetStatePropertyAll(Colors.white),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.brandNavy, borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.brandSoft,
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.text),
      secondaryLabelStyle: const TextStyle(fontSize: 13, color: AppColors.brand, fontWeight: FontWeight.w600),
      checkmarkColor: AppColors.brand,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
    ),
    scrollbarTheme: ScrollbarThemeData(
      radius: const Radius.circular(8),
      thickness: const WidgetStatePropertyAll(6),
      thumbColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.18)),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.sidebar, shape: RoundedRectangleBorder()),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: bentuk,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        foregroundColor: AppColors.text,
        side: const BorderSide(color: AppColors.border),
        backgroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w500),
        shape: bentuk,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: bentuk,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}
