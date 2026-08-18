/*
Tujuan: Token warna aplikasi yang mendukung mode gelap (default) dan mode
        terang ala web SM-MIS (design.md: paper #f9f7f6, ink #261910,
        accent #f97316).
Caller: Seluruh halaman/widget, app_theme.dart.
Dependensi: Flutter material Color.
Main Functions: Getter warna per mode (isLight).
Side Effects: Global static flag isLight; harus di-set sebelum build.
*/
import 'package:flutter/material.dart';

/// Token warna SM Workshop — mode gelap (luxury) & mode terang (web light).
class AppColors {
  AppColors._();

  /// Mode aktif. Di-set oleh root app sebelum build (lihat main.dart).
  static bool isLight = false;

  // ─── Backgrounds ─────────────────────────────────────────
  static Color get background => isLight ? lightBackground : darkBackground;
  static Color get surfaceCard => isLight ? lightSurface : darkSurfaceCard;
  static Color get surfaceNav => isLight ? lightSurface : darkSurfaceNav;
  static Color get surfaceInput => isLight ? lightInput : darkSurfaceInput;

  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color darkSurfaceCard = Color(0xFF131313);
  static const Color darkSurfaceNav = Color(0xFF0D0D0D);
  static const Color darkSurfaceInput = Color(0xFF1A1A1A);

  static const Color lightBackground = Color(0xFFF9F7F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightInput = Color(0xFFF2EFEB);

  // ─── Borders ─────────────────────────────────────────────
  static Color get border => isLight ? lightBorder : darkBorder;
  static Color get borderSubtle => isLight ? lightInput : darkBorderSubtle;

  static const Color darkBorder = Color(0xFF2A2A2A);
  static const Color darkBorderSubtle = Color(0xFF1F1F1F);
  static const Color lightBorder = Color(0xFFE4E1DC);

  // ─── Brand Colors ────────────────────────────────────────
  // Gelap: gold luxury. Terang: amber/oranye web (#f97316).
  static Color get gold => isLight ? lightGold : darkGold;
  static Color get goldBright => isLight ? lightGoldBright : darkGoldBright;
  static Color get orange => isLight ? lightOrange : darkOrange;

  static const Color darkGold = Color(0xFFC9A85F);
  static const Color darkGoldBright = Color(0xFFD4AF37);
  static const Color darkOrange = Color(0xFFD97D3A);

  static const Color lightGold = Color(0xFFF97316);
  static const Color lightGoldBright = Color(0xFFFF8A3D);
  static const Color lightOrange = Color(0xFFD97D3A);

  // ─── Text Colors ─────────────────────────────────────────
  static Color get textPrimary => isLight ? lightInk : darkTextPrimary;
  static Color get textSecondary => isLight ? lightInkMuted : darkTextSecondary;
  static Color get textTertiary => isLight ? lightInkSubtle : darkTextTertiary;
  static Color get textMuted => isLight ? lightInkMuted : darkTextMuted;
  static Color get textDisabled => isLight ? lightInkDisabled : darkTextDisabled;

  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFAAAAAA);
  static const Color darkTextTertiary = Color(0xFF999999);
  static const Color darkTextMuted = Color(0xFF888888);
  static const Color darkTextDisabled = Color(0xFF666666);

  static const Color lightInk = Color(0xFF261910);
  static const Color lightInkMuted = Color(0xFF565658);
  static const Color lightInkSubtle = Color(0xFF6F6F71);
  static const Color lightInkDisabled = Color(0xFFA8A29A);

  // ─── Status Colors ───────────────────────────────────────
  static Color get statusInProgress => gold;
  static Color get statusToDo => orange;
  static Color get statusDone => isLight ? lightDone : darkDone;
  static Color get statusLocked => isLight ? lightLocked : darkLocked;

  static const Color darkDone = Color(0xFF4CAF50);
  static const Color darkLocked = Color(0xFFE53935);
  static const Color lightDone = Color(0xFF2D7645);
  static const Color lightLocked = Color(0xFFB13A25);

  // ─── Gradients ───────────────────────────────────────────
  static LinearGradient get goldGradient => LinearGradient(
    colors: [goldBright, gold],
  );

  static LinearGradient get backgroundGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isLight
        ? [Color(0xFFFFFFFF), Color(0xFFF9F7F6), Color(0xFFF2EFEB)]
        : [Color(0xFF1A1A1A), Color(0xFF0D0D0D), Color(0xFF000000)],
  );

  static LinearGradient get cardGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: isLight
        ? [Color(0xFFFFFFFF), Color(0xFFF9F7F6)]
        : [surfaceCard, Color(0xFF0F0F0F)],
  );
}
