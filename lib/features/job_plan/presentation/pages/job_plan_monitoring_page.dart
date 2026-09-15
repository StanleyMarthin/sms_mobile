/*
Tujuan: Halaman monitoring KD/QA Job Plan V2.
Caller: Router /job-plans/v2/monitoring dan widget test.
Dependensi: JobPlanRepository, CommandMetadata, JobPlan entity.
Main Functions: JobPlanMonitoringPage.
Side Effects: HTTP POST monitor saat VERIFY dikirim.
*/
library;

import 'package:flutter/material.dart';
import 'package:sm_system/core/di/injection.dart';

import '../../domain/entities/job_plan.dart';
import '../../domain/repositories/job_plan_repository.dart';

class JobPlanMonitoringPage extends StatefulWidget {
  const JobPlanMonitoringPage({super.key, this.initialPlans, this.repository});

  final List<JobPlan>? initialPlans;
  final JobPlanRepository? repository;

  @override
  State<JobPlanMonitoringPage> createState() => _JobPlanMonitoringPageState();
}

class _JobPlanMonitoringPageState extends State<JobPlanMonitoringPage> {
  late Future<List<JobPlan>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.initialPlans != null
        ? Future.value(widget.initialPlans!)
        : (widget.repository ?? sl<JobPlanRepository>()).listV2Plans();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JobPlan>>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final plans = snapshot.data!;
        if (plans.isEmpty) {
          return const Center(child: Text('Tidak ada monitoring'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: plans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _MonitoringCard(plan: plans[index], onVerify: _verify),
        );
      },
    );
  }

  Future<void> _verify(
    JobPlan plan,
    int verifiedTotal,
    int? progress,
    String? note,
  ) async {
    final repo = widget.repository ?? sl<JobPlanRepository>();
    await repo.monitorV2Plan(
      planId: plan.id,
      metadata: CommandMetadata(
        commandId:
            'mobile-v2-monitor-${plan.id}-${DateTime.now().microsecondsSinceEpoch}',
        expectedVersion: plan.version,
      ),
      verifiedTotalMinutes: verifiedTotal,
      progressSeen: progress,
      note: note,
    );
    setState(() => _future = repo.listV2Plans());
  }
}

class _MonitoringCard extends StatelessWidget {
  const _MonitoringCard({required this.plan, required this.onVerify});

  final JobPlan plan;
  final Future<void> Function(JobPlan, int, int?, String?) onVerify;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.panelName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Target: ${_hours(plan.countdownTargetMinutes)}'),
            Text('Allocated: ${_hours((plan.targetHours * 60).round())}'),
            Text('Worked: ${_hours(plan.accumulatedMinutes)}'),
            Text('Verified: ${_hours(plan.verifiedMinutes)}'),
            Text('Pending: ${_hours(plan.unverifiedMinutes)}'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _openVerify(context),
              child: const Text('VERIFY'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openVerify(BuildContext context) async {
    final total = TextEditingController(text: '${plan.verifiedMinutes}');
    final progress = TextEditingController();
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: total,
              decoration: const InputDecoration(
                labelText: 'Verified Total Minutes',
              ),
            ),
            TextField(
              controller: progress,
              decoration: const InputDecoration(labelText: 'Progress'),
            ),
            TextField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await onVerify(
        plan,
        int.tryParse(total.text) ?? plan.verifiedMinutes,
        int.tryParse(progress.text),
        note.text.trim(),
      );
    }
  }

  String _hours(int minutes) {
    if (minutes <= 0) return '0 jam';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours jam' : '$hours jam $rest menit';
  }
}
