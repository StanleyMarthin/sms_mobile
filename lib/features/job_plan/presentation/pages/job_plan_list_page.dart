/*
Tujuan: Halaman list read-only Job Plan V2 dengan filter dasar.
Caller: Router /job-plans/v2.
Dependensi: JobPlanRepository, JobPlan entity, JobPlanV2StateMapper.
Main Functions: JobPlanListPage.
Side Effects: HTTP GET list Job Plan V2.
*/
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sm_system/core/di/injection.dart';

import '../../domain/entities/job_plan.dart';
import '../../domain/repositories/job_plan_repository.dart';
import '../utils/job_plan_v2_state_mapper.dart';

class JobPlanListPage extends StatelessWidget {
  const JobPlanListPage({
    super.key,
    this.date,
    this.unitId,
    this.employeeId,
    this.approvalState,
    this.executionState,
    this.repository,
  });

  final String? date;
  final String? unitId;
  final String? employeeId;
  final String? approvalState;
  final String? executionState;
  final JobPlanRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? sl<JobPlanRepository>();
    return FutureBuilder<List<JobPlan>>(
      future: repo.listV2Plans(
        date: date,
        unitId: unitId,
        employeeId: employeeId,
        approvalState: approvalState,
        executionState: executionState,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final plans = snapshot.data!;
        if (plans.isEmpty) {
          return const Center(child: Text('Tidak ada job plan'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: plans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _JobPlanCard(plan: plans[index]),
        );
      },
    );
  }
}

class _JobPlanCard extends StatelessWidget {
  const _JobPlanCard({required this.plan});

  final JobPlan plan;

  @override
  Widget build(BuildContext context) {
    final status = JobPlanV2StateMapper.approvalLabel(plan.approvalState);
    return Card(
      child: ListTile(
        title: Text(plan.unitName),
        subtitle: Text(
          'Panel: ${plan.panelName}\n'
          'Countdown: ${plan.resolvedCountdownName}\n'
          '${plan.scheduleTimeLabel}\n'
          'Status: $status',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/job-plan/${plan.id}'),
      ),
    );
  }
}
