import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/data/dummy_data.dart';

/// Division filter dropdown for ADV/PM roles.
///
/// Shows a dropdown of available divisions that the user can filter by.
/// Hidden for OP and KD roles (they see fixed scope).
class TaskDivisionFilter extends StatelessWidget {
  /// Currently selected division ID (null = all divisions).
  final String? selectedDivisionId;

  /// Callback when a division is selected.
  final ValueChanged<String?> onDivisionChanged;

  const TaskDivisionFilter({
    super.key,
    this.selectedDivisionId,
    required this.onDivisionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedDivisionId,
          hint: const Text(
            'Semua Divisi',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          icon: const Icon(Icons.arrow_drop_down,
              color: AppColors.gold, size: 20),
          isExpanded: true,
          dropdownColor: AppColors.surfaceCard,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Semua Divisi',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ),
            ...DummyDivisions.all.map((div) {
              final id = div['id'].toString();
              final name = div['name'] as String;
              return DropdownMenuItem<String?>(
                value: id,
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary)),
              );
            }),
          ],
          onChanged: onDivisionChanged,
        ),
      ),
    );
  }
}

/// Unit filter dropdown for ADV/PM roles.
///
/// Shows a dropdown of available units (cars) that the user can filter by.
class TaskUnitFilter extends StatelessWidget {
  /// Currently selected unit ID (null = all units).
  final String? selectedUnitId;

  /// Callback when a unit is selected.
  final ValueChanged<String?> onUnitChanged;

  const TaskUnitFilter({
    super.key,
    this.selectedUnitId,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: selectedUnitId,
          hint: const Text(
            'Semua Unit',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          icon: const Icon(Icons.arrow_drop_down,
              color: AppColors.gold, size: 20),
          isExpanded: true,
          dropdownColor: AppColors.surfaceCard,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Semua Unit',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ),
            ...DummyCars.all.map((car) {
              final id = car['id'] as String;
              final name = car['unit_name'] as String;
              return DropdownMenuItem<String?>(
                value: id,
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary)),
              );
            }),
          ],
          onChanged: onUnitChanged,
        ),
      ),
    );
  }
}
