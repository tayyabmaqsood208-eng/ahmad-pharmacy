import 'package:flutter/material.dart';

class AppColors {
  // Primary Teal/Emerald Brand Colors
  static const Color primary = Color(0xFF0F9D8B);
  static const Color primaryHover = Color(0xFF0B8576);
  static const Color primaryLight = Color(0xFFE6F5F3);
  static const Color primaryDark = Color(0xFF0A6B5F);

  // Background & Surfaces
  static const Color sidebarBg = Color(0xFFF4F6F8);
  static const Color sidebarDarkBg = Color(0xFF1E293B);
  static const Color bodyBg = Color(0xFFFAFAFA);
  static const Color bodyDarkBg = Color(0xFF0F172A);
  static const Color cardBg = Colors.white;
  static const Color cardDarkBg = Color(0xFF1E293B);

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1F26);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Colors.white;

  // Status & Utility Colors
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);

  static const Color danger = Color(0xFFEF4444);
  static const Color dangerLight = Color(0xFFFEE2E2);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Dividers & Borders
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF334155);

  // Dynamic Context-Aware Theme Resolvers
  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.textPrimary;
  }

  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
  }

  static Color getBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? AppColors.borderDark : AppColors.border;
  }

  static Color getCardBg(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? AppColors.cardDarkBg : AppColors.cardBg;
  }
}
