/*
Tujuan: Halaman detail read-only Job Plan V2.
Caller: Router /job-plan/:id dan widget test.
Dependensi: JobPlanRepository, JobPlan entity, JobPlanV2StateMapper.
Main Functions: JobPlanDetailPage.
Side Effects: HTTP GET V2 detail saat initialPlan tidak diberikan.
*/
library;

import 'package:flutter/material.dart';
import 'package:sm_system/core/di/injection.dart';

import '../../domain/entities/job_plan.dart';
import '../../domain/repositories/job_plan_repository.dart';
import '../utils/job_plan_v2_state_mapper.dart';

class JobPlanDetailPage extends StatefulWidget {
  const JobPlanDetailPage({
    super.key,
    required this.planId,
    this.initialPlan,
    this.repository,
  });

  final String planId;
  final JobPlan? initialPlan;
  final JobPlanRepository? repository;

  @override
  State<JobPlanDetailPage> createState() => _JobPlanDetailPageState();
}

class _JobPlanDetailPageState extends State<JobPlanDetailPage> {
  late final Future<JobPlan> _future = widget.initialPlan != null
      ? Future.value(widget.initialPlan)
      : (widget.repository ?? sl<JobPlanRepository>()).getV2Plan(widget.planId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<JobPlan>(
      future: _future,
      initialData: widget.initialPlan,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _JobPlanDetailView(plan: snapshot.data!);
      },
    );
  }
}

class _JobPlanDetailView extends StatelessWidget {
  const _JobPlanDetailView({required this.plan});

  final JobPlan plan;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(plan.unitName, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(plan.panelName, style: Theme.of(context).textTheme.titleMedium),
        const Divider(height: 28),
        _InfoRow(label: 'Countdown', value: plan.resolvedCountdownName),
        _InfoRow(label: 'PIC', value: plan.resolvedEmployeeName),
        _InfoRow(label: 'Schedule', value: _dateLabel(plan.resolvedTaskDate)),
        _InfoRow(label: '', value: plan.scheduleTimeLabel),
        const Divider(height: 28),
        _InfoRow(
          label: 'Approval',
          value: JobPlanV2StateMapper.approvalLabel(plan.approvalState),
        ),
        _InfoRow(
          label: 'Execution',
          value: JobPlanV2StateMapper.executionLabel(plan.executionState),
        ),
        _InfoRow(
          label: 'Ledger',
          value: JobPlanV2StateMapper.ledgerLabel(plan.ledgerState),
        ),
        _InfoRow(label: 'Version', value: '${plan.version}'),
      ],
    );
  }

  String _dateLabel(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sept',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
