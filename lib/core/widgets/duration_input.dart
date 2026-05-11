import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// A UX-friendly duration input widget that splits hours and minutes.
class DurationInput extends StatefulWidget {
  const DurationInput({
    super.key,
    this.initialHours,
    required this.onChanged,
    this.labelText,
    this.isTripleHours = false,
  });

  final double? initialHours;
  final ValueChanged<double> onChanged;
  final String? labelText;

  /// When true, allows up to 999 hours (HHH:mm). Otherwise 99 hours (HH:mm).
  final bool isTripleHours;

  @override
  State<DurationInput> createState() => _DurationInputState();
}

class _DurationInputState extends State<DurationInput> {
  late final TextEditingController _hoursCtrl;
  late final TextEditingController _minsCtrl;

  @override
  void initState() {
    super.initState();
    final totalHours = widget.initialHours ?? 0.0;
    final h = totalHours.floor();
    final m = ((totalHours - h) * 60).round();

    _hoursCtrl = TextEditingController(
      text: h > 0 ? h.toString().padLeft(widget.isTripleHours ? 3 : 2, '0') : '',
    );
    _minsCtrl = TextEditingController(
      text: m > 0 ? m.toString().padLeft(2, '0') : '',
    );
  }

  @override
  void didUpdateWidget(DurationInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialHours != oldWidget.initialHours) {
      final totalHours = widget.initialHours ?? 0.0;
      final h = totalHours.floor();
      final m = ((totalHours - h) * 60).round();
      
      final hText = h.toString().padLeft(widget.isTripleHours ? 3 : 2, '0');
      final mText = m.toString().padLeft(2, '0');

      // Only update if text actually changes to avoid cursor jumping
      if (h > 0 && _hoursCtrl.text != hText) {
        _hoursCtrl.text = hText;
      } else if (h == 0 && _hoursCtrl.text.isNotEmpty) {
        _hoursCtrl.clear();
      }
      
      if (m > 0 && _minsCtrl.text != mText) {
        _minsCtrl.text = mText;
      } else if (m == 0 && _minsCtrl.text.isNotEmpty) {
        _minsCtrl.clear();
      }
    }
  }

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _minsCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    final h = int.tryParse(_hoursCtrl.text) ?? 0;
    final m = int.tryParse(_minsCtrl.text) ?? 0;
    widget.onChanged(h + (m / 60.0));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelText != null) ...[
          Text(
            widget.labelText!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            // Hours
            Expanded(
              child: TextField(
                controller: _hoursCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.isTripleHours ? 3 : 2),
                ],
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: widget.isTripleHours ? '000' : '00',
                  suffixText: 'j',
                  suffixStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: AppColors.surfaceInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.gold),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (_) => _notify(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                ':',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Minutes
            Expanded(
              child: TextField(
                controller: _minsCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: '00',
                  suffixText: 'm',
                  suffixStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: AppColors.surfaceInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.gold),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) {
                  final val = int.tryParse(v) ?? 0;
                  if (val > 59) {
                    _minsCtrl.text = '59';
                    _minsCtrl.selection = TextSelection.collapsed(offset: 2);
                  }
                  _notify();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
