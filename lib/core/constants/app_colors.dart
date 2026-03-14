import 'package:flutter/material.dart';

/// Color constants for the SM Workshop dark luxury theme.
///
/// Based on the High-Fidelity UI mockup for Classic Car Restoration
/// workshop management system.
class AppColors {
  AppColors._();

  // ─── Backgrounds ─────────────────────────────────────────
  static const Color background = Color(0xFF0A0A0A);
  static const Color surfaceCard = Color(0xFF131313);
  static const Color surfaceNav = Color(0xFF0D0D0D);
  static const Color surfaceInput = Color(0xFF1A1A1A);

  // ─── Borders ─────────────────────────────────────────────
  static const Color border = Color(0xFF2A2A2A);
  static const Color borderSubtle = Color(0xFF1F1F1F);

  // ─── Brand Colors ────────────────────────────────────────
  static const Color gold = Color(0xFFC9A85F);
  static const Color goldBright = Color(0xFFD4AF37);
  static const Color orange = Color(0xFFD97D3A);

  // ─── Text Colors ─────────────────────────────────────────
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textTertiary = Color(0xFF999999);
  static const Color textMuted = Color(0xFF888888);
  static const Color textDisabled = Color(0xFF666666);

  // ─── Status Colors ───────────────────────────────────────
  static const Color statusInProgress = gold;
  static const Color statusToDo = orange;
  static const Color statusDone = Color(0xFF4CAF50);
  static const Color statusLocked = Color(0xFFE53935);

  // ─── Gradients ───────────────────────────────────────────
  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldBright, gold],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D), Color(0xFF000000)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceCard, Color(0xFF0F0F0F)],
  );
}
