/*
Tujuan: Halaman read-only tracking approval Job Plan V2.
Caller: Router /job-plans/v2/approval-tracking dan widget test.
Dependensi: JobPlanRepository, JobPlan entity.
Main Functions: JobPlanApprovalTrackingPage.
Side Effects: HTTP GET Job Plan V2 list.
*/
library;

import 'package:flutter/material.dart';
import 'package:sm_system/core/di/injection.dart';

import '../../domain/entities/job_plan.dart';
import '../../domain/repositories/job_plan_repository.dart';

class JobPlanApprovalTrackingPage extends StatelessWidget {
  const JobPlanApprovalTrackingPage({
    super.key,
    this.initialPlans,
    this.repository,
  });

  final List<JobPlan>? initialPlans;
  final JobPlanRepository? repository;

  @override
  Widget build(BuildContext context) {
    final future = initialPlans != null
        ? Future.value(initialPlans!)
        : (repository ?? sl<JobPlanRepository>()).listV2Plans();
    return FutureBuilder<List<JobPlan>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final plans = snapshot.data!;
        if (plans.isEmpty) {
          return const Center(child: Text('Tidak ada tracking'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: plans.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Text(
                'Approval Tracking',
                style: Theme.of(context).textTheme.titleLarge,
              );
            }
            return _TrackingCard(plan: plans[index - 1]);
          },
        );
      },
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.plan});

  final JobPlan plan;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.unitName, style: Theme.of(context).textTheme.titleMedium),
            Text(plan.panelName),
            Text('Created: Done'),
            Text('Division: ${_step('DIVISION_REVIEW')}'),
            Text('KP: ${_step('UNIT_REVIEW')}'),
            Text('MP: ${_step('MANAGEMENT_REVIEW')}'),
          ],
        ),
      ),
    );
  }

  String _step(String stage) {
    final state = plan.approvalState ?? '';
    if (state == stage) return 'Waiting';
    const order = ['DIVISION_REVIEW', 'UNIT_REVIEW', 'MANAGEMENT_REVIEW'];
    if (state == 'APPROVED') return 'Done';
    if (state == 'REJECTED') return 'Rejected';
    return order.indexOf(state) > order.indexOf(stage) ? 'Done' : '-';
  }
}
