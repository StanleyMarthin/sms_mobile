/*
Tujuan: Daftar pekerjaan gabungan dari dual-read backend dalam modul Job Plan.
Caller: JobPlanPage.
Dependensi: JobPlanRepository, JobPlan entity, JobPlanStateMapper.
Main Functions: JobPlanList.
Side Effects: HTTP GET list Job Plan.
*/
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sm_system/core/di/injection.dart';

import '../../domain/entities/job_plan.dart';
import '../../domain/entities/job_plan_options.dart';
import '../../domain/repositories/job_plan_repository.dart';
import '../utils/job_plan_state_mapper.dart';
import 'package:sm_system/core/errors/error_message.dart';

class JobPlanList extends StatefulWidget {
  const JobPlanList({
    super.key,
    this.date,
    this.divisionId,
    this.unitId,
    this.employeeId,
    this.approvalState,
    this.executionState,
    this.repository,
  });

  final String? date;
  final String? divisionId;
  final String? unitId;
  final String? employeeId;
  final String? approvalState;
  final String? executionState;
  final JobPlanRepository? repository;

  @override
  State<JobPlanList> createState() => _JobPlanListState();
}

class _JobPlanListState extends State<JobPlanList> {
  late final JobPlanRepository _repository =
      widget.repository ?? sl<JobPlanRepository>();
  late DateTime _date = DateTime.tryParse(widget.date ?? '') ?? DateTime.now();
  late String? _divisionId = _emptyAsNull(widget.divisionId);
  late String? _unitId = _emptyAsNull(widget.unitId);
  late String? _employeeId = _emptyAsNull(widget.employeeId);
  late Future<List<JobPlan>> _future = _load();

  Future<List<JobPlan>> _load() => _repository
      .listOperationalPlans(
        date: _dateString(_date),
        approvalState: widget.approvalState,
        executionState: widget.executionState,
      )
      .timeout(const Duration(seconds: 3));

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JobPlan>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _future = _load()),
              child: Text(
                friendlyMessage(
                  snapshot.error,
                  fallback: 'Gagal memuat pekerjaan. Coba lagi',
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final allPlans = snapshot.data!;
        final visiblePlans = _applyLocalFilters(allPlans);
        final options = _optionsFromPlans(allPlans);
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: [
              _JobPlanFilters(
                date: _date,
                divisions: options.divisions,
                units: options.units,
                employees: options.employees,
                divisionId: _divisionId,
                unitId: _unitId,
                employeeId: _employeeId,
                onDateChanged: (date) {
                  setState(() {
                    _date = date;
                    _future = _load();
                  });
                },
                onDivisionChanged: (id) {
                  setState(() {
                    _divisionId = id;
                    _unitId = null;
                    _employeeId = null;
                  });
                },
                onUnitChanged: (id) => setState(() {
                  _unitId = id;
                }),
                onEmployeeChanged: (id) => setState(() {
                  _employeeId = id;
                }),
              ),
              const SizedBox(height: 12),
              ..._items(visiblePlans),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _items(List<JobPlan> plans) {
    if (plans.isEmpty) {
      return const [
        SizedBox(height: 80),
        Center(child: Text('Tidak ada pekerjaan')),
      ];
    }
    return [
      for (var i = 0; i < plans.length; i++) ...[
        _JobPlanCard(plan: plans[i]),
        if (i < plans.length - 1) const SizedBox(height: 8),
      ],
    ];
  }

  List<JobPlan> _applyLocalFilters(List<JobPlan> plans) {
    return plans.where((plan) {
      if (_divisionId != null && !_matchesDivision(plan, _divisionId!)) {
        return false;
      }
      if (_unitId != null && plan.unitId != _unitId && plan.carId != _unitId) {
        return false;
      }
      if (_employeeId != null && plan.resolvedEmployeeId != _employeeId) {
        return false;
      }
      return true;
    }).toList();
  }

  JobPlanOptions _optionsFromPlans(List<JobPlan> plans) {
    final selectedDivision = _divisionId;
    final selectedUnit = _unitId;
    return JobPlanOptions(
      divisions: _uniqueOptions(
        plans,
        idOf: (plan) => _optionId(plan.divisionId, plan.assignedDivision),
        labelOf: (plan) => plan.assignedDivision,
      ),
      units: _uniqueOptions(
        plans.where(
          (plan) =>
              selectedDivision == null ||
              _matchesDivision(plan, selectedDivision),
        ),
        idOf: (plan) => _optionId(plan.unitId, plan.carId),
        labelOf: (plan) => plan.unitName,
      ),
      employees: _uniqueOptions(
        plans.where((plan) {
          final divisionOk =
              selectedDivision == null ||
              _matchesDivision(plan, selectedDivision);
          final unitOk =
              selectedUnit == null ||
              plan.unitId == selectedUnit ||
              plan.carId == selectedUnit;
          return divisionOk && unitOk;
        }),
        idOf: (plan) => plan.resolvedEmployeeId,
        labelOf: (plan) => plan.resolvedEmployeeName,
      ),
    );
  }

  bool _matchesDivision(JobPlan plan, String value) =>
      plan.divisionId == value || plan.assignedDivision == value;

  List<JobPlanOption> _uniqueOptions(
    Iterable<JobPlan> plans, {
    required String Function(JobPlan) idOf,
    required String Function(JobPlan) labelOf,
  }) {
    final byId = <String, JobPlanOption>{};
    for (final plan in plans) {
      final id = idOf(plan).trim();
      if (id.isEmpty) continue;
      byId[id] = JobPlanOption(
        id: id,
        label: _fallbackLabel(labelOf(plan), id),
      );
    }
    final values = byId.values.toList();
    values.sort((a, b) => a.label.compareTo(b.label));
    return values;
  }

  String _optionId(String? preferred, String fallback) {
    final text = preferred?.trim() ?? '';
    return text.isNotEmpty ? text : fallback.trim();
  }

  String _fallbackLabel(String preferred, String fallback) {
    final text = preferred.trim();
    return text.isNotEmpty ? text : fallback;
  }
}

class _JobPlanCard extends StatelessWidget {
  const _JobPlanCard({required this.plan});

  final JobPlan plan;

  @override
  Widget build(BuildContext context) {
    final status = JobPlanStateMapper.approvalLabel(plan.approvalState);
    return Card(
      child: ListTile(
        title: Text(plan.unitName),
        subtitle: Text(
          'Panel: ${plan.panelName}\n'
          'Jobdesc: ${plan.resolvedCountdownName}\n'
          '${plan.scheduleTimeLabel}\n'
          'Status: $status',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/job-plan/${plan.id}'),
      ),
    );
  }
}

class _JobPlanFilters extends StatelessWidget {
  const _JobPlanFilters({
    required this.date,
    required this.divisions,
    required this.units,
    required this.employees,
    required this.divisionId,
    required this.unitId,
    required this.employeeId,
    required this.onDateChanged,
    required this.onDivisionChanged,
    required this.onUnitChanged,
    required this.onEmployeeChanged,
  });

  final DateTime date;
  final List<JobPlanOption> divisions;
  final List<JobPlanOption> units;
  final List<JobPlanOption> employees;
  final String? divisionId;
  final String? unitId;
  final String? employeeId;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String?> onDivisionChanged;
  final ValueChanged<String?> onUnitChanged;
  final ValueChanged<String?> onEmployeeChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tanggal'),
              subtitle: Text(_dateString(date)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) onDateChanged(picked);
              },
            ),
            const SizedBox(height: 8),
            _optionDropdown(
              label: 'Divisi',
              value: divisionId,
              options: divisions,
              emptyLabel: 'Semua divisi',
              onChanged: onDivisionChanged,
            ),
            const SizedBox(height: 8),
            _optionDropdown(
              label: 'Unit',
              value: unitId,
              options: units,
              emptyLabel: 'Semua unit',
              onChanged: onUnitChanged,
            ),
            const SizedBox(height: 8),
            _optionDropdown(
              label: 'PIC',
              value: employeeId,
              options: employees,
              emptyLabel: 'Semua PIC',
              onChanged: onEmployeeChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionDropdown({
    required String label,
    required String? value,
    required List<JobPlanOption> options,
    required String emptyLabel,
    required ValueChanged<String?> onChanged,
  }) {
    final ids = options.map((item) => item.id).toSet();
    final selected = ids.contains(value) ? value : '';
    return DropdownButtonFormField<String>(
      key: ValueKey('$label:$selected:${options.length}'),
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        DropdownMenuItem(value: '', child: Text(emptyLabel)),
        for (final item in options)
          DropdownMenuItem(value: item.id, child: Text(item.label)),
      ],
      onChanged: (id) => onChanged(_emptyAsNull(id)),
    );
  }
}

String _dateString(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String? _emptyAsNull(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}
