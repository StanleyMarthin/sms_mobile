/*
Tujuan: Halaman approval Job Plan V2 untuk approve/correct/reject.
Caller: Router /job-plans/v2/approval.
Dependensi: JobPlanRepository, CommandMetadata, JobPlanV2StateMapper.
Main Functions: JobPlanApprovalPage.
Side Effects: HTTP PUT Job Plan V2 saat user mengirim command approval.
*/
library;

import 'package:flutter/material.dart';
import 'package:sm_system/core/di/injection.dart';

import '../../domain/entities/job_plan.dart';
import '../../domain/repositories/job_plan_repository.dart';
import '../utils/job_plan_v2_command_feedback.dart';
import '../utils/job_plan_v2_state_mapper.dart';

class JobPlanApprovalPage extends StatefulWidget {
  const JobPlanApprovalPage({super.key, this.initialPlans, this.repository});

  final List<JobPlan>? initialPlans;
  final JobPlanRepository? repository;

  @override
  State<JobPlanApprovalPage> createState() => _JobPlanApprovalPageState();
}

class _JobPlanApprovalPageState extends State<JobPlanApprovalPage> {
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
        final plans = snapshot.data!
            .where((plan) => _pendingStates.contains(plan.approvalState))
            .toList();
        if (plans.isEmpty) {
          return const Center(child: Text('Tidak ada approval'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: plans.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _ApprovalCard(plan: plans[index], onAction: _sendAction),
        );
      },
    );
  }

  static const _pendingStates = {
    'DIVISION_REVIEW',
    'UNIT_REVIEW',
    'MANAGEMENT_REVIEW',
  };

  Future<void> _sendAction(
    JobPlan plan,
    String action, {
    int? plannedStartMinute,
    int? plannedWorkMinutes,
    String? rejectReason,
  }) async {
    final repo = widget.repository ?? sl<JobPlanRepository>();
    try {
      await repo.mutateV2Approval(
        planId: plan.id,
        action: action,
        metadata: CommandMetadata(
          commandId: _commandId(action, plan.id),
          expectedVersion: plan.version,
        ),
        plannedStartMinute: plannedStartMinute,
        plannedWorkMinutes: plannedWorkMinutes,
        rejectReason: rejectReason,
      );
      setState(() {
        _future = repo.listV2Plans();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(JobPlanV2CommandFeedback.message(e))),
      );
      if (JobPlanV2CommandFeedback.shouldRefresh(e)) {
        setState(() {
          _future = repo.listV2Plans();
        });
      }
    }
  }

  String _commandId(String action, String planId) {
    return 'mobile-v2-$action-$planId-${DateTime.now().microsecondsSinceEpoch}';
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({required this.plan, required this.onAction});

  final JobPlan plan;
  final Future<void> Function(
    JobPlan plan,
    String action, {
    int? plannedStartMinute,
    int? plannedWorkMinutes,
    String? rejectReason,
  })
  onAction;

  @override
  Widget build(BuildContext context) {
    final state = JobPlanV2StateMapper.approvalLabel(plan.approvalState);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(plan.unitName, style: Theme.of(context).textTheme.titleMedium),
            Text(plan.panelName),
            Text(state),
            Text(
              'Menunggu: ${JobPlanV2StateMapper.waitingFor(plan.approvalState)}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton(
                  onPressed: () => onAction(plan, 'approve'),
                  child: const Text('Approve'),
                ),
                OutlinedButton(
                  onPressed: () => _correct(context),
                  child: const Text('Correction'),
                ),
                TextButton(
                  onPressed: () => _reject(context),
                  child: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _correct(BuildContext context) async {
    final start = TextEditingController(text: '${plan.startMinute ?? 0}');
    final minutes = TextEditingController(text: '${plan.durationMinutes ?? 0}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Correction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: start,
              decoration: const InputDecoration(labelText: 'Start Minute'),
            ),
            TextField(
              controller: minutes,
              decoration: const InputDecoration(labelText: 'Work Minutes'),
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
      await onAction(
        plan,
        'correct',
        plannedStartMinute: int.tryParse(start.text),
        plannedWorkMinutes: int.tryParse(minutes.text),
      );
    }
  }

  Future<void> _reject(BuildContext context) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Alasan'),
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
      await onAction(plan, 'reject', rejectReason: reason.text.trim());
    }
  }
}
