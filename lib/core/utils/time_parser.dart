import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TimeParser {
  /// Converts a decimal hour (e.g. 2.5) to HHH:mm format (e.g. "002:30").
  static String formatDecimalToHHmm(double decimalHours) {
    if (decimalHours <= 0) return '';
    final h = decimalHours.floor();
    final m = ((decimalHours - h) * 60).round();
    if (h == 0 && m == 0) return '';
    return '${h.toString().padLeft(3, '0')}:${m.toString().padLeft(2, '0')}';
  }

  /// Parses HHH:mm (e.g. "008:30"), HH:mm (e.g. "08:30"), or decimal string to decimal hours.
  /// Returns null if input is empty or invalid.
  static double? parseHHmmToDecimal(String input) {
    final cleanInput = input.trim().replaceAll(',', '.');
    if (cleanInput.isEmpty) return null;

    if (cleanInput.contains(':')) {
      final parts = cleanInput.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h == null || m == null) return null;
        if (m < 0 || m > 59) return null;
        return h + (m / 60.0);
      }
    }

    return double.tryParse(cleanInput);
  }

  /// Parses HH:MM clock time string to [TimeOfDay]. Returns null if invalid.
  static TimeOfDay? parseTimeOfDay(String input) {
    final clean = input.trim();
    if (clean.contains(':')) {
      final parts = clean.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
          return TimeOfDay(hour: h, minute: m);
        }
      }
    }
    return null;
  }
}

/// TextInputFormatter for duration in HHH:MM format (e.g. "008:30").
/// User types only digits; colon is auto-inserted after 3 digits.
/// Max input: "999:59" = 6 chars.
class HHHMMFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');

    final String formatted;
    if (digits.length <= 3) {
      formatted = digits;
    } else {
      final h = digits.substring(0, 3);
      final m = digits.substring(3, digits.length.clamp(3, 5));
      formatted = '$h:$m';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// TextInputFormatter for clock time in HH:MM format (e.g. "08:30").
/// User types only digits; colon is auto-inserted after 2 digits.
/// Max input: "23:59" = 5 chars.
class HHMMFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');

    final String formatted;
    if (digits.length <= 2) {
      formatted = digits;
    } else {
      final h = digits.substring(0, 2);
      final m = digits.substring(2, digits.length.clamp(2, 4));
      formatted = '$h:$m';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
