/*
Tujuan: Halaman approval Job Plan untuk approve/correct/reject.
Caller: Job Plan page approval tab and widget test.
Dependensi: JobPlanRepository, CommandMetadata, JobPlanStateMapper.
Main Functions: JobPlanApprovalPage.
Side Effects: HTTP PUT Job Plan saat user mengirim command approval.
*/
library;

import 'package:flutter/material.dart';
import 'package:sm_system/core/di/injection.dart';

import '../../domain/entities/job_plan.dart';
import '../../domain/repositories/job_plan_repository.dart';
import '../utils/job_plan_command_feedback.dart';
import '../utils/job_plan_state_mapper.dart';
import 'package:sm_system/core/errors/error_message.dart';

class JobPlanApprovalPage extends StatefulWidget {
  const JobPlanApprovalPage({
    super.key,
    this.initialPlans,
    this.repository,
    this.onLegacyPlanTap,
  });

  final List<JobPlan>? initialPlans;
  final JobPlanRepository? repository;
  final Future<void> Function(JobPlan)? onLegacyPlanTap;

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
        : _load();
  }

  Future<List<JobPlan>> _load() =>
      (widget.repository ?? sl<JobPlanRepository>()).listOperationalPlans(
        view: 'approval',
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JobPlan>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(() => _future = _load()),
              child: Text(
                friendlyMessage(
                  snapshot.error,
                  fallback: 'Gagal memuat approval. Coba lagi',
                ),
              ),
            ),
          );
        }
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
          itemBuilder: (context, index) {
            final plan = plans[index];
            if (plan.readSource == 'MYSQL_LEGACY') {
              return Card(
                child: ListTile(
                  title: Text(plan.unitName),
                  subtitle: Text(
                    '${plan.panelName}\n${JobPlanStateMapper.approvalLabel(plan.approvalState)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: plan.readOnly || widget.onLegacyPlanTap == null
                      ? null
                      : () async {
                          await widget.onLegacyPlanTap!(plan);
                          if (mounted) setState(() => _future = _load());
                        },
                ),
              );
            }
            if (plan.readOnly) {
              return ListTile(
                title: Text(plan.unitName),
                subtitle: Text(plan.panelName),
              );
            }
            return _ApprovalCard(plan: plan, onAction: _sendAction);
          },
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
      await repo.mutateApproval(
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
        _future = _load();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(JobPlanCommandFeedback.message(e))),
      );
      if (JobPlanCommandFeedback.shouldRefresh(e)) {
        setState(() {
          _future = _load();
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
    final state = JobPlanStateMapper.approvalLabel(plan.approvalState);
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
              'Menunggu: ${JobPlanStateMapper.waitingFor(plan.approvalState)}',
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
