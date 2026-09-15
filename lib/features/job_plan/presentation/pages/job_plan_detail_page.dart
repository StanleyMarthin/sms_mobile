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
        const _SectionTitle('Work'),
        _InfoRow(label: 'Unit', value: plan.unitName),
        _InfoRow(label: 'Panel', value: plan.panelName),
        _InfoRow(label: 'Countdown', value: plan.resolvedCountdownName),
        _InfoRow(label: 'Job Description', value: plan.description),
        _InfoRow(label: 'PIC', value: plan.resolvedEmployeeName),
        _InfoRow(label: 'Division', value: plan.assignedDivision),
        const Divider(height: 28),
        const _SectionTitle('Schedule'),
        _InfoRow(label: 'Tanggal', value: _dateLabel(plan.resolvedTaskDate)),
        _InfoRow(label: 'Jam Mulai', value: plan.startTime),
        _InfoRow(label: 'Jam', value: plan.scheduleTimeLabel),
        _InfoRow(label: 'Durasi', value: _minuteDuration(plan.durationMinutes)),
        const Divider(height: 28),
        const _SectionTitle('Approval Timeline'),
        ..._approvalSteps(
          plan.approvalState,
        ).map((step) => _StepRow(label: step.$1, marker: step.$2)),
        const Divider(height: 28),
        const _SectionTitle('Execution'),
        _InfoRow(
          label: 'Current',
          value: JobPlanV2StateMapper.executionLabel(plan.executionState),
        ),
        const Divider(height: 28),
        const _SectionTitle('Monitoring'),
        _InfoRow(
          label: 'Verified Hours',
          value: _minuteDuration(plan.verifiedMinutes),
        ),
        _InfoRow(
          label: 'Pending Verification',
          value: _minuteDuration(plan.unverifiedMinutes),
        ),
        _InfoRow(label: 'Progress', value: '${plan.progress}%'),
        _InfoRow(
          label: 'Last Update',
          value: _dateTimeLabel(plan.updatedAt ?? plan.createdAt),
        ),
        const Divider(height: 28),
        const _SectionTitle('Ledger'),
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

  String _dateTimeLabel(DateTime? value) {
    if (value == null) return '-';
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '${_dateLabel(value.toIso8601String())} $hh:$mm';
  }

  String _minuteDuration(int? minutes) {
    final value = minutes ?? 0;
    return '${value ~/ 60} jam ${value % 60} menit';
  }

  List<(String, String)> _approvalSteps(String? current) {
    const steps = [
      ['DRAFT', 'Draft'],
      ['DIVISION_REVIEW', 'Review Divisi'],
      ['UNIT_REVIEW', 'Review KP'],
      ['MANAGEMENT_REVIEW', 'Review Management'],
      ['APPROVED', 'Approved'],
    ];
    final index = steps.indexWhere((step) => step.first == current);
    return [
      for (var i = 0; i < steps.length; i++)
        (
          steps[i][1],
          i < index
              ? '✓'
              : i == index
              ? '●'
              : '-',
        ),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.marker});

  final String label;
  final String marker;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text(marker)),
          Expanded(child: Text(label)),
        ],
      ),
    );
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
