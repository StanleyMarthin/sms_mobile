import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TimeParser {
  /// Converts a decimal hour (e.g. 2.5) to HHH:mm or HH:mm format.
  static String formatDecimalToHHmm(double decimalHours, {bool isTriple = true}) {
    if (decimalHours <= 0) return '';
    final h = decimalHours.floor();
    final m = ((decimalHours - h) * 60).round();
    if (h == 0 && m == 0) return '';
    return '${h.toString().padLeft(isTriple ? 3 : 2, '0')}:${m.toString().padLeft(2, '0')}';
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

  /// Formats a numeric-only duration input into HHH:MM.
  /// Examples:
  ///  - "8" -> "008:00"
  ///  - "830" -> "008:30"
  ///  - "10000" -> "100:00"
  static String formatDurationDigits(String digits) {
    final clean = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return '';

    int hours;
    int minutes;

    if (clean.length <= 2) {
      hours = int.parse(clean);
      minutes = 0;
    } else {
      hours = int.parse(clean.substring(0, clean.length - 2));
      minutes = int.parse(clean.substring(clean.length - 2));
    }

    hours += minutes ~/ 60;
    minutes = minutes % 60;

    return '${hours.toString().padLeft(3, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// Formats a [DateTime] to ISO 8601 with timezone offset (e.g. "+07:00").
  /// This prevents 7-hour timezone mismatch between Mobile and Backend.
  static String formatIsoWithOffset(DateTime dt) {
    final String iso = dt.toIso8601String();
    if (iso.endsWith('Z')) return iso; // Already UTC
    
    final offset = dt.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final hours = offset.inHours.abs().toString().padLeft(2, '0');
    final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    
    return '$iso$sign$hours:$minutes';
  }

  /// Normalizes any clock-related candidate (seconds, "HH:mm", ISO string) to "HH:mm".
  static String? normalizeClock(Object? value) {
    if (value == null) return null;
    if (value is num) {
      final totalMinutes = (value.toDouble() / 60).round();
      final hours = ((totalMinutes ~/ 60) % 24).toString().padLeft(2, '0');
      final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
      return '$hours:$minutes';
    }

    final raw = value.toString().trim();
    if (raw.isEmpty || raw == '-' || raw.toLowerCase() == 'null') return null;

    final numeric = double.tryParse(raw);
    if (numeric != null) {
      final totalMinutes = (numeric / 60).round();
      final hours = ((totalMinutes ~/ 60) % 24).toString().padLeft(2, '0');
      final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
      return '$hours:$minutes';
    }

    final directMatch = RegExp(r'(\d{1,2}):(\d{2})(?::\d{2})?').firstMatch(raw);
    if (directMatch != null) {
      final hour = directMatch.group(1)!.padLeft(2, '0');
      final minute = directMatch.group(2)!;
      return '$hour:$minute';
    }

    final normalizedIsoSource = raw.contains(' ') && !raw.contains('T')
        ? raw.replaceFirst(' ', 'T')
        : raw;
    final parsedDateTime = DateTime.tryParse(normalizedIsoSource);
    if (parsedDateTime == null) return null;

    final local = parsedDateTime.isUtc ? parsedDateTime.toLocal() : parsedDateTime;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Picks the first non-null normalized clock value from candidates.
  static String pickClock(Iterable<Object?> candidates, {String fallback = '-'}) {
    for (final candidate in candidates) {
      final normalized = normalizeClock(candidate);
      if (normalized != null) return normalized;
    }
    return fallback;
  }

  /// Extracts a clock range from text (e.g. "08:00 - 10:00") and returns start or finish.
  static String? extractNoteRangeClock(Object? value, {required bool takeStart}) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final match = RegExp(
      r'(\d{1,2}:\d{2})(?::\d{2})?\s*-\s*(\d{1,2}:\d{2})(?::\d{2})?',
    ).firstMatch(raw);
    if (match == null) return null;

    return normalizeClock(takeStart ? match.group(1) : match.group(2));
  }

  /// Extracts the first clock pattern found in text.
  static String? extractFirstClockFromText(Object? value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    final match = RegExp(r'(\d{1,2}:\d{2})(?::\d{2})?').firstMatch(raw);
    if (match == null) return null;
    return normalizeClock(match.group(1));
  }
}

/// TextInputFormatter for duration in HHH:MM format (e.g. "008:30").
/// User types only digits; the final 2 digits are treated as minutes.
/// Examples:
///  - 8 => 008:00
///  - 830 => 008:30
///  - 10000 => 100:00
class HHHMMFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final formatted = TimeParser.formatDurationDigits(digits);

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
