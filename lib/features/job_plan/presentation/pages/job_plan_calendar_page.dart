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
    this.divisionId,
    this.repository,
    this.initialPlans,
  });

  final String? date;
  final String? unitId;
  final String? employeeId;
  final String? divisionId;
  final JobPlanRepository? repository;
  final List<JobPlan>? initialPlans;

  @override
  State<JobPlanCalendarPage> createState() => _JobPlanCalendarPageState();
}

class _JobPlanCalendarPageState extends State<JobPlanCalendarPage> {
  late final _date = TextEditingController(text: widget.date ?? '');
  late final _unit = TextEditingController(text: widget.unitId ?? '');
  late final _employee = TextEditingController(text: widget.employeeId ?? '');
  late final _division = TextEditingController(text: widget.divisionId ?? '');
  late Future<List<JobPlan>> _future;
  bool _weekView = false;

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
    _division.dispose();
    super.dispose();
  }

  Future<List<JobPlan>> _load() {
    if (widget.initialPlans != null) return Future.value(widget.initialPlans!);
    return (widget.repository ?? sl<JobPlanRepository>()).listV2Plans(
      date: _emptyToNull(_date.text),
      unitId: _emptyToNull(_unit.text),
      employeeId: _emptyToNull(_employee.text),
      divisionId: _emptyToNull(_division.text),
      calendarView: _weekView ? 'week' : 'day',
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
          ..sort((a, b) {
            final byDate = a.resolvedTaskDate.compareTo(b.resolvedTaskDate);
            if (byDate != 0) return byDate;
            return (a.startMinute ?? 0).compareTo(b.startMinute ?? 0);
          });
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
        TextField(
          controller: _division,
          decoration: const InputDecoration(labelText: 'Division ID'),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Day')),
            ButtonSegment(value: true, label: Text('Week')),
          ],
          selected: {_weekView},
          onSelectionChanged: (value) => setState(() {
            _weekView = value.first;
            _future = _load();
          }),
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
