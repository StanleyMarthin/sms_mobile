import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// Reusable date-filter bar used across all KD dashboard tabs.
///
/// Displays the currently selected date with left/right navigation arrows
/// and a tap-to-pick calendar. Calls [onDateChanged] whenever the user
/// selects a new date.
class DateFilterBar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  /// Optional label shown before the date (e.g. "Filter Tanggal:").
  final String? label;

  const DateFilterBar({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
    this.label,
  });

  // ── Indonesian day/month lookup ────────────────────────
  static const _dayNames = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];
  static const _monthNames = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  String _formatDate(DateTime d) {
    final day = _dayNames[d.weekday - 1];
    return '$day, ${d.day} ${_monthNames[d.month]} ${d.year}';
  }

  bool get _isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          // Left arrow
          _arrowButton(Icons.chevron_left, () {
            onDateChanged(selectedDate.subtract(const Duration(days: 1)));
          }),

          const SizedBox(width: 4),

          // Tappable date display
          Expanded(
            child: GestureDetector(
              onTap: () => _pickDate(context),
              child: Column(
                children: [
                  if (label != null)
                    Text(
                      label!,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted.withValues(alpha: 0.7),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 14, color: AppColors.gold),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(selectedDate),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                  if (_isToday)
                    const Text(
                      'Hari ini',
                      style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Right arrow
          _arrowButton(Icons.chevron_right, () {
            onDateChanged(selectedDate.add(const Duration(days: 1)));
          }),
        ],
      ),
    );
  }

  Widget _arrowButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 22, color: AppColors.gold),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (ctx, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.gold,
              onPrimary: AppColors.background,
              surface: AppColors.surfaceCard,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onDateChanged(picked);
  }
}
