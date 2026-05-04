import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/di/injection.dart';

/// Division filter dropdown for ADV/PM roles.
///
/// Shows a dropdown of available divisions that the user can filter by.
/// Hidden for OP and KD roles (they see fixed scope).
class TaskDivisionFilter extends StatefulWidget {
  final String? selectedDivisionId;
  final ValueChanged<String?> onDivisionChanged;

  const TaskDivisionFilter({
    super.key,
    this.selectedDivisionId,
    required this.onDivisionChanged,
  });

  @override
  State<TaskDivisionFilter> createState() => _TaskDivisionFilterState();
}

class _TaskDivisionFilterState extends State<TaskDivisionFilter> {
  List<Map<String, dynamic>> _divisions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await sl<ApiClient>().get(ApiEndpoints.jobPlanDropdowns);
      final data = res.data['data'] ?? res.data;
      if (!mounted) return;
      if (data != null && data['divisions'] is List) {
        setState(() {
          _divisions = (data['divisions'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)
          )
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: widget.selectedDivisionId,
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
            ..._divisions.map((div) {
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
          onChanged: widget.onDivisionChanged,
        ),
      ),
    );
  }
}

/// Unit filter dropdown for ADV/PM roles.
///
/// Shows a dropdown of available units (cars) that the user can filter by.
class TaskUnitFilter extends StatefulWidget {
  final String? selectedUnitId;
  final ValueChanged<String?> onUnitChanged;

  const TaskUnitFilter({
    super.key,
    this.selectedUnitId,
    required this.onUnitChanged,
  });

  @override
  State<TaskUnitFilter> createState() => _TaskUnitFilterState();
}

class _TaskUnitFilterState extends State<TaskUnitFilter> {
  List<Map<String, dynamic>> _cars = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final res = await sl<ApiClient>().get(ApiEndpoints.jobPlanDropdowns);
      final data = res.data['data'] ?? res.data;
      if (!mounted) return;
      if (data != null && data['cars'] is List) {
        setState(() {
          _cars = (data['cars'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold)
          )
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceInput,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: widget.selectedUnitId,
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
            ..._cars.map((car) {
              final id = car['id']?.toString() ?? '';
              final name = car['unit_name'] as String? ?? 'Unknown';
              return DropdownMenuItem<String?>(
                value: id,
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textPrimary)),
              );
            }),
          ],
          onChanged: widget.onUnitChanged,
        ),
      ),
    );
  }
}
