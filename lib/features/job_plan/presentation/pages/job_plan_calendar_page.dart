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

class JobPlanCalendarPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final future = initialPlans != null
        ? Future.value(initialPlans!)
        : (repository ?? sl<JobPlanRepository>()).listV2Plans(
            date: date,
            unitId: unitId,
            employeeId: employeeId,
          );
    return FutureBuilder<List<JobPlan>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final plans = [...snapshot.data!]
          ..sort((a, b) => (a.startMinute ?? 0).compareTo(b.startMinute ?? 0));
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: plans.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final plan = plans[index];
            return ListTile(
              title: Text(plan.scheduleTimeLabel),
              subtitle: Text('${plan.unitName}\n${plan.panelName}'),
            );
          },
        );
      },
    );
  }
}
