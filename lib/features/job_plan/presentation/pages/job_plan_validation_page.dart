/*
Tujuan: Halaman final labor validation Job Plan V2.
Caller: Router /job-plans/v2/validation dan widget test.
Dependensi: JobPlanRepository, CommandMetadata, JobPlan entity.
Main Functions: JobPlanValidationPage.
Side Effects: HTTP POST validate saat PASS dikirim.
*/
library;

import 'package:flutter/material.dart';
import 'package:sm_system/core/di/injection.dart';

import '../../domain/entities/job_plan.dart';
import '../../domain/repositories/job_plan_repository.dart';
import '../utils/job_plan_v2_command_feedback.dart';

class JobPlanValidationPage extends StatefulWidget {
  const JobPlanValidationPage({super.key, this.initialPlans, this.repository});

  final List<JobPlan>? initialPlans;
  final JobPlanRepository? repository;

  @override
  State<JobPlanValidationPage> createState() => _JobPlanValidationPageState();
}

class _JobPlanValidationPageState extends State<JobPlanValidationPage> {
  late Future<List<JobPlan>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<JobPlan>> _load() {
    if (widget.initialPlans != null) return Future.value(widget.initialPlans!);
    return (widget.repository ?? sl<JobPlanRepository>()).listV2Plans(
      executionState: 'FINISHED_PENDING_VALIDATION',
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
        final plans = snapshot.data!
            .where(
              (plan) => plan.executionState == 'FINISHED_PENDING_VALIDATION',
            )
            .toList();
        if (plans.isEmpty) {
          return const Center(child: Text('Tidak ada validasi'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: plans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _ValidationCard(plan: plans[index], onPass: _pass),
        );
      },
    );
  }

  Future<void> _pass(JobPlan plan, String? note) async {
    final repo = widget.repository ?? sl<JobPlanRepository>();
    try {
      await repo.validateV2Plan(
        planId: plan.id,
        metadata: CommandMetadata(
          commandId:
              'mobile-v2-validate-${plan.id}-${DateTime.now().microsecondsSinceEpoch}',
          expectedVersion: plan.version,
        ),
        verifiedTotalMinutes: plan.accumulatedMinutes,
        progressSeen: 100,
        note: note,
      );
      setState(() {
        _future = _load();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(JobPlanV2CommandFeedback.message(e))),
      );
      if (JobPlanV2CommandFeedback.shouldRefresh(e)) {
        setState(() {
          _future = _load();
        });
      }
    }
  }
}

class _ValidationCard extends StatelessWidget {
  const _ValidationCard({required this.plan, required this.onPass});

  final JobPlan plan;
  final Future<void> Function(JobPlan plan, String? note) onPass;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              plan.description,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(plan.panelName),
            Text('Actual: ${_hours(plan.accumulatedMinutes)}'),
            const Text('Status:'),
            const Text('Waiting Validation'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => _openPass(context),
              child: const Text('PASS'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPass(BuildContext context) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Final Validation'),
        content: TextField(
          controller: note,
          decoration: const InputDecoration(labelText: 'Note'),
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
    if (ok == true) await onPass(plan, note.text.trim());
  }

  String _hours(int minutes) {
    if (minutes <= 0) return '0 jam';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours jam' : '$hours jam $rest menit';
  }
}
