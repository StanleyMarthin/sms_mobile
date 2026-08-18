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
  static final _dayNames = [
    'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];
  static final _monthNames = [
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
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.gold.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            // Left arrow
            _arrowButton(Icons.chevron_left, () {
              onDateChanged(selectedDate.subtract(Duration(days: 1)));
            }),
  
            SizedBox(width: 4),
  
            // Tappable date display
            Expanded(
              child: GestureDetector(
                onTap: () => _pickDate(context),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Ensure it doesn't try to take infinite height
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
                      mainAxisSize: MainAxisSize.min, // Avoid overflow in nested rows
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 14, color: AppColors.gold),
                        SizedBox(width: 6),
                        Flexible( // Allow text to shrink if needed
                          child: Text(
                            _formatDate(selectedDate),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.gold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (_isToday)
                      Text(
                        'Hari ini',
                        style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
            ),
  
            SizedBox(width: 4),
  
            // Right arrow
            _arrowButton(Icons.chevron_right, () {
              onDateChanged(selectedDate.add(Duration(days: 1)));
            }),
          ],
        ),
      ),
    );
  }

  Widget _arrowButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(4),
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
            colorScheme: ColorScheme.dark(
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
