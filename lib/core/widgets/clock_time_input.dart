import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// A UX-friendly clock time input widget that splits hours and minutes (HH:mm).
class ClockTimeInput extends StatefulWidget {
  const ClockTimeInput({
    super.key,
    required this.initialTime,
    required this.onChanged,
    this.labelText,
    this.onTapIcon,
  });

  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onChanged;
  final String? labelText;
  final VoidCallback? onTapIcon;

  @override
  State<ClockTimeInput> createState() => _ClockTimeInputState();
}

class _ClockTimeInputState extends State<ClockTimeInput> {
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _minsCtrl;

  @override
  void initState() {
    super.initState();
    _hoursCtrl = TextEditingController(
      text: widget.initialTime.hour.toString().padLeft(2, '0'),
    );
    _minsCtrl = TextEditingController(
      text: widget.initialTime.minute.toString().padLeft(2, '0'),
    );
  }

  @override
  void didUpdateWidget(ClockTimeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTime != oldWidget.initialTime) {
      final hText = widget.initialTime.hour.toString().padLeft(2, '0');
      final mText = widget.initialTime.minute.toString().padLeft(2, '0');
      if (_hoursCtrl.text != hText) _hoursCtrl.text = hText;
      if (_minsCtrl.text != mText) _minsCtrl.text = mText;
    }
  }

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _minsCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    final h = (int.tryParse(_hoursCtrl.text) ?? 0) % 24;
    final m = (int.tryParse(_minsCtrl.text) ?? 0) % 60;
    widget.onChanged(TimeOfDay(hour: h, minute: m));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          Text(
            widget.labelText!,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceInput,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _hoursCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'HH',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          final h = int.tryParse(v) ?? 0;
                          if (h > 23) {
                            _hoursCtrl.text = '23';
                            _hoursCtrl.selection = TextSelection.collapsed(offset: 2);
                          }
                          _notify();
                        },
                      ),
                    ),
                    Text(
                      ':',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _minsCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'mm',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                          isDense: true,
                        ),
                        onChanged: (v) {
                          final m = int.tryParse(v) ?? 0;
                          if (m > 59) {
                            _minsCtrl.text = '59';
                            _minsCtrl.selection = TextSelection.collapsed(offset: 2);
                          }
                          _notify();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.onTapIcon != null)
              IconButton(
                onPressed: widget.onTapIcon,
                icon: Icon(Icons.schedule_rounded, color: AppColors.gold, size: 20),
                padding: EdgeInsets.only(left: 4),
                constraints: BoxConstraints(),
              ),
          ],
        ),
      ],
    );
  }
}
