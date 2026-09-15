/*
Tujuan: Kalender planner Job Plan V2 berbasis data backend.
Caller: Router /job-plans/v2/calendar.
Dependensi: JobPlanRepository dan JobPlan entity.
Main Functions: JobPlanCalendarPage.
Side Effects: HTTP GET Job Plan V2 list.
*/
library;

import 'package:flutter/material.dart';
import 'package:sm_system/core/di/injection.dart';

import '../../domain/entities/job_plan.dart';
import '../../domain/repositories/job_plan_repository.dart';

class JobPlanCalendarPage extends StatefulWidget {
  const JobPlanCalendarPage({
    super.key,
    this.date,
    this.unitId,
    this.employeeId,
    this.repository,
    this.initialPlans,
  });

  final String? date;
  final String? unitId;
  final String? employeeId;
  final JobPlanRepository? repository;
  final List<JobPlan>? initialPlans;

  @override
  State<JobPlanCalendarPage> createState() => _JobPlanCalendarPageState();
}

class _JobPlanCalendarPageState extends State<JobPlanCalendarPage> {
  late final _date = TextEditingController(text: widget.date ?? '');
  late final _unit = TextEditingController(text: widget.unitId ?? '');
  late final _employee = TextEditingController(text: widget.employeeId ?? '');
  late Future<List<JobPlan>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _date.dispose();
    _unit.dispose();
    _employee.dispose();
    super.dispose();
  }

  Future<List<JobPlan>> _load() {
    if (widget.initialPlans != null) return Future.value(widget.initialPlans!);
    return (widget.repository ?? sl<JobPlanRepository>()).listV2Plans(
      date: _emptyToNull(_date.text),
      unitId: _emptyToNull(_unit.text),
      employeeId: _emptyToNull(_employee.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JobPlan>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final plans = [...snapshot.data!]
          ..sort((a, b) => (a.startMinute ?? 0).compareTo(b.startMinute ?? 0));
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: plans.length + 1,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            if (index == 0) return _filters();
            final plan = plans[index - 1];
            return ListTile(
              title: Text(plan.scheduleTimeLabel),
              subtitle: Text('${plan.unitName}\n${plan.panelName}'),
            );
          },
        );
      },
    );
  }

  Widget _filters() {
    return Column(
      children: [
        TextField(
          controller: _date,
          decoration: const InputDecoration(labelText: 'Tanggal'),
        ),
        TextField(
          controller: _unit,
          decoration: const InputDecoration(labelText: 'Unit ID'),
        ),
        TextField(
          controller: _employee,
          decoration: const InputDecoration(labelText: 'PIC ID'),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () => setState(() {
              _future = _load();
            }),
            child: const Text('Filter'),
          ),
        ),
      ],
    );
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
