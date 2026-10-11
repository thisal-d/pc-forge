import 'package:flutter/material.dart';

/// Centralized color palette matching PCForge Shop design specifications
class AppColors {
  // Brand & Accents
  static const Color primaryBlue = Color(0xFF0066FF);
  static const Color primaryDark = Color(0xFF0F172A);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color specText = Color(0xFF475569);
  
  // Surfaces & Backgrounds
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8FAFC);
  static const Color specPillBackground = Color(0xFFF1F5F9);
  static const Color imageContainerBg = Color(0xFFF8FAFC);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFE2E8F0);

  // Status & Badges
  static const Color stockGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color alertRed = Color(0xFFEF4444);

  // Gradients
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0A3BB6), Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient badgeGradient = LinearGradient(
    colors: [Color(0xFF0062FF), Color(0xFF00A3FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Minimal Soft Elevation Shadow
  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.04),
      blurRadius: 10,
      spreadRadius: 0,
      offset: Offset(0, 2),
    ),
  ];
}
