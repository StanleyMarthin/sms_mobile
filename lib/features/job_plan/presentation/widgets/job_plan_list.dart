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
  List<JobPlanOption> _divisions = const [];
  List<JobPlanOption> _units = const [];
  List<JobPlanOption> _employees = const [];
  bool _filtersLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<List<JobPlan>> _load() => _repository.listOperationalPlans(
    date: _dateString(_date),
    divisionId: _divisionId,
    unitId: _unitId,
    employeeId: _employeeId,
    approvalState: widget.approvalState,
    executionState: widget.executionState,
  );

  Future<void> _loadFilters() async {
    try {
      final options = await _repository.getOptions(divisionId: _divisionId);
      if (!mounted) return;
      setState(() {
        _divisions = options.divisions;
        _units = options.units;
        _employees = options.employees;
        _filtersLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _filtersLoading = false);
    }
  }

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
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: [
              _JobPlanFilters(
                date: _date,
                divisions: _divisions,
                units: _units,
                employees: _employees,
                divisionId: _divisionId,
                unitId: _unitId,
                employeeId: _employeeId,
                loading: _filtersLoading,
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
                    _filtersLoading = true;
                    _future = _load();
                  });
                  _loadFilters();
                },
                onUnitChanged: (id) => setState(() {
                  _unitId = id;
                  _future = _load();
                }),
                onEmployeeChanged: (id) => setState(() {
                  _employeeId = id;
                  _future = _load();
                }),
              ),
              const SizedBox(height: 12),
              ..._items(snapshot.data!),
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
    required this.loading,
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
  final bool loading;
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
              emptyLabel: loading ? 'Memuat divisi...' : 'Semua divisi',
              onChanged: onDivisionChanged,
            ),
            const SizedBox(height: 8),
            _optionDropdown(
              label: 'Unit',
              value: unitId,
              options: units,
              emptyLabel: loading ? 'Memuat unit...' : 'Semua unit',
              onChanged: onUnitChanged,
            ),
            const SizedBox(height: 8),
            _optionDropdown(
              label: 'PIC',
              value: employeeId,
              options: employees,
              emptyLabel: loading ? 'Memuat PIC...' : 'Semua PIC',
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
