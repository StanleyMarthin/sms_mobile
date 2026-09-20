/*
Tujuan: Daftar pekerjaan gabungan dari dual-read backend dalam modul Job Plan.
Caller: JobPlanPage.
Dependensi: JobPlanRepository, JobPlan entity, JobPlanStateMapper.
Main Functions: JobPlanList.
Side Effects: HTTP GET list Job Plan.
*/
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sm_system/core/di/injection.dart';

import '../../domain/entities/job_plan.dart';
import '../../domain/repositories/job_plan_repository.dart';
import '../utils/job_plan_state_mapper.dart';
import 'package:sm_system/core/errors/error_message.dart';

class JobPlanList extends StatefulWidget {
  const JobPlanList({
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
  State<JobPlanList> createState() => _JobPlanListState();
}

class _JobPlanListState extends State<JobPlanList> {
  late Future<List<JobPlan>> _future = _load();

  Future<List<JobPlan>> _load() =>
      (widget.repository ?? sl<JobPlanRepository>()).listOperationalPlans(
        date: widget.date,
        unitId: widget.unitId,
        employeeId: widget.employeeId,
        approvalState: widget.approvalState,
        executionState: widget.executionState,
      );

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

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
                  fallback: 'Gagal memuat pekerjaan. Coba lagi',
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final plans = snapshot.data!;
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            itemCount: plans.isEmpty ? 1 : plans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => plans.isEmpty
                ? const Center(child: Text('Tidak ada job plan'))
                : _JobPlanCard(plan: plans[index]),
          ),
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
    final status = JobPlanStateMapper.approvalLabel(plan.approvalState);
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
