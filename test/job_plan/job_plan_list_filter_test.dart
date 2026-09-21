/*
Tujuan: Mengunci daftar Job Plan V2 agar memakai filter tanggal-divisi-unit-PIC dan label Jobdesc.
Caller: Flutter test runner.
Dependensi: JobPlanList, JobPlanRepository fake, JobPlanOptions.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/di/injection.dart';
import 'package:sm_system/core/session/session_manager.dart';
import 'package:sm_system/features/job_plan/presentation/pages/job_plan_page.dart';
import 'package:sm_system/features/job_plan/domain/entities/job_plan.dart';
import 'package:sm_system/features/job_plan/domain/entities/job_plan_options.dart';
import 'package:sm_system/features/job_plan/domain/repositories/job_plan_repository.dart';
import 'package:sm_system/features/job_plan/presentation/widgets/job_plan_list.dart';

class _FakeRepository implements JobPlanRepository {
  final calls = <Map<String, String?>>[];

  @override
  Future<Map<String, dynamic>?> getDraft({required String userId}) async =>
      null;

  @override
  Future<List<JobPlan>> listOperationalPlans({
    String view = 'browse',
    int page = 1,
    int limit = 20,
    String? unitId,
    String? employeeId,
    String? date,
    String? divisionId,
    String? approvalState,
    String? executionState,
  }) async {
    calls.add({
      'date': date,
      'divisionId': divisionId,
      'unitId': unitId,
      'employeeId': employeeId,
    });
    return [
      JobPlan(
        planId: 'PLAN-1',
        coreId: 'CORE-1',
        carId: 'UNIT-1',
        sourceType: 'COUNTDOWN',
        sourceRefId: 'CORE-1',
        unitName: 'MB220S',
        panelName: 'Door RH',
        assignedDivision: 'Interior',
        assignedUserId: 'EMP-1',
        assignedTo: 'Budi',
        description: 'Painting Door RH',
        countdownName: 'Painting Door RH',
        targetHours: 4,
        workDate: '2026-09-21',
        taskDate: '2026-09-21',
        startTime: '08:00',
        finishTime: '12:00',
        isOvertime: false,
        deadline: '',
        status: 'APPROVED',
        note: '',
        approvalState: 'APPROVED',
      ),
    ];
  }

  @override
  Future<JobPlanOptions> getOptions({
    String? divisionId,
    String? unitId,
    String? coreId,
  }) async {
    return const JobPlanOptions(
      divisions: [JobPlanOption(id: 'DIV-1', label: 'Interior')],
      units: [JobPlanOption(id: 'UNIT-1', label: 'MB220S')],
      employees: [JobPlanOption(id: 'EMP-1', label: 'Budi')],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PlannerSession extends SessionManager {
  @override
  bool get isKdAccess => true;
  @override
  bool get mobileEnabled => true;
  @override
  bool hasPerm(String permission) => permission == Perms.jobPlanCreate;
  @override
  bool hasAnyPerm(List<String> permissions) => permissions.any(hasPerm);
}

void main() {
  testWidgets('planner retains Rencana and the existing create source sheet', (
    tester,
  ) async {
    sl.registerSingleton<JobPlanRepository>(_FakeRepository());
    sl.registerSingleton<SessionManager>(_PlannerSession());
    addTearDown(sl.reset);

    await tester.pumpWidget(const MaterialApp(home: JobPlanPage()));
    await tester.pumpAndSettle();
    expect(find.text('Rencana'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Buat Rencana Kerja Dari:'), findsOneWidget);
    expect(find.text('Jobdesc List'), findsOneWidget);
    expect(find.text('Work Order / WOV'), findsOneWidget);
    expect(find.text('Additional Task'), findsOneWidget);
    expect(find.text('Core ID'), findsNothing);
  });

  testWidgets('JobPlanList uses hierarchy filters and Jobdesc label', (
    tester,
  ) async {
    final repository = _FakeRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: JobPlanList(
            date: '2026-09-21',
            divisionId: 'DIV-1',
            unitId: 'UNIT-1',
            employeeId: 'EMP-1',
            repository: repository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.calls.single['date'], '2026-09-21');
    expect(repository.calls.single['divisionId'], 'DIV-1');
    expect(repository.calls.single['unitId'], 'UNIT-1');
    expect(repository.calls.single['employeeId'], 'EMP-1');
    expect(find.text('Tanggal'), findsOneWidget);
    expect(find.text('Divisi'), findsOneWidget);
    expect(find.text('Unit'), findsOneWidget);
    expect(find.text('PIC'), findsOneWidget);
    expect(find.textContaining('Jobdesc: Painting Door RH'), findsOneWidget);
  });
}
