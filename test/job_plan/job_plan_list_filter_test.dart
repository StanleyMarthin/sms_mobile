/*
Tujuan: Mengunci flow mobile Job Plan agar UI lama tetap dipakai dan list read model tidak memanggil dropdown V2.
Caller: Flutter test runner.
Dependensi: JobPlanPage, JobPlanList, JobPlanRepository fake, JobPlanOptions.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:fpdart/fpdart.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/di/injection.dart';
import 'package:sm_system/core/errors/failures.dart';
import 'package:sm_system/core/session/session_manager.dart';
import 'package:sm_system/features/countdown/domain/entities/countdown_entities.dart';
import 'package:sm_system/features/countdown/domain/repositories/countdown_repository.dart';
import 'package:sm_system/features/job_plan/presentation/pages/job_plan_page.dart';
import 'package:sm_system/features/job_plan/domain/entities/job_plan.dart';
import 'package:sm_system/features/job_plan/domain/entities/job_plan_options.dart';
import 'package:sm_system/features/job_plan/domain/repositories/job_plan_repository.dart';
import 'package:sm_system/features/job_plan/presentation/widgets/job_plan_list.dart';

class _FakeRepository implements JobPlanRepository {
  final calls = <Map<String, String?>>[];
  final savedDrafts = <List<Map<String, dynamic>>>[];
  int optionCalls = 0;

  @override
  Future<List<JobPlan>> getPlans() async => const [];

  @override
  Future<Map<String, dynamic>?> getDraft({required String userId}) async =>
      null;

  @override
  Future<List<Map<String, dynamic>>> getDropdownUsers({
    required String divisionId,
    String? search,
    int limit = 200,
  }) async {
    return const [
      {'id': 'EMP-1', 'full_name': 'Budi', 'employee_id': 'EMP-1'},
    ];
  }

  @override
  Future<void> saveDraft({
    required String userId,
    required List<Map<String, dynamic>> items,
    required String sourceType,
    bool replaceItems = true,
    String? note,
  }) async {
    savedDrafts.add(items);
  }

  @override
  Future<fp.Either<Failure, Map<String, dynamic>>> getApprovalRaw({
    String? divisionId,
    String? unitId,
    String? taskDate,
    int limit = 100,
    int offset = 0,
  }) async {
    return const fp.Right({'items': <Map<String, dynamic>>[]});
  }

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
        unitId: 'UNIT-1',
        divisionId: 'DIV-1',
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
    optionCalls++;
    return const JobPlanOptions(
      divisions: [JobPlanOption(id: 'DIV-1', label: 'Interior')],
      units: [JobPlanOption(id: 'UNIT-1', label: 'MB220S')],
      employees: [JobPlanOption(id: 'EMP-1', label: 'Budi')],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCountdownRepository implements CountdownRepository {
  @override
  Future<List<CountdownUnit>> getUnits({
    required String? role,
    required String? division,
  }) async {
    return [
      CountdownUnit(
        carId: 'UNIT-1',
        unitName: 'MB220S',
        owner: 'Workshop',
        progress: 10,
        status: 'PROSES',
        division: 'Interior',
      ),
    ];
  }

  @override
  Future<List<CountdownDivision>> getDivisions(String carId) async {
    return [
      CountdownDivision(
        divisionId: 1,
        divisionName: 'Interior',
        code: 'INT',
        divisionProgress: 10,
      ),
    ];
  }

  @override
  Future<List<CountdownSection>> getSections({
    required String carId,
    required int divisionId,
    String? search,
    String? status,
    bool plannable = false,
  }) async {
    return [
      CountdownSection(
        panelId: 10,
        sectionName: 'Door RH',
        section: 'Door',
        totalJobdesc: 1,
        totalRemainingHours: 4,
        totalTargetHours: 4,
        sectionProgress: 0,
        sectionStatus: 'PROSES',
      ),
    ];
  }

  @override
  Future<List<CountdownJobdesc>> getJobdescs({
    required String carId,
    required int divisionId,
    required int panelId,
    String? search,
    String? status,
    bool plannable = false,
  }) async {
    return [
      CountdownJobdesc(
        id: 'CORE-1',
        carId: 'UNIT-1',
        divisionId: '1',
        panelName: 'Door RH',
        sectionName: 'Door RH',
        jobdesc: 'Painting Door RH',
        taskCategory: 'MAIN',
        progress: 0,
        status: 'PROSES',
        targetHoursInitial: 4,
        timeExtensionHours: 0,
        targetHoursRevised: 4,
        totalActualHours: 0,
        remainingHours: 4,
        startDate: '2026-09-21',
        deadlineDate: '2026-09-30',
        qcLastStatus: null,
        qcValidationStatus: null,
        qcResultStatus: null,
        qcEstimatedReworkHours: null,
        qcReworkDeadlineDate: null,
        qcAdvisorNotes: null,
        availablePlanHours: 4,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _PlannerSession extends SessionManager {
  @override
  String? get employeeId => 'KD-1';
  @override
  String? get divisionName => 'Interior';
  @override
  String? get role => 'KETUA DIVISI';
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

  testWidgets('planner can create a draft from existing Jobdesc flow', (
    tester,
  ) async {
    final repository = _FakeRepository();
    sl.registerSingleton<JobPlanRepository>(repository);
    sl.registerSingleton<CountdownRepository>(_FakeCountdownRepository());
    sl.registerSingleton<SessionManager>(_PlannerSession());
    addTearDown(sl.reset);

    await tester.pumpWidget(const MaterialApp(home: JobPlanPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jobdesc List'));
    await tester.pumpAndSettle();

    expect(find.text('Job Plan dari Countdown'), findsOneWidget);
    await tester.tap(find.text('Cari Unit Countdown'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MB220S').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih Panel di Unit ini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Door RH • Door'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih Tugas di Panel ini'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Painting Door RH').last);
    await tester.tap(find.text('PILIH PEKERJAAN'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Pilih Anggota'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Pilih Anggota'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budi').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('SIMPAN KE DRAFT'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));

    expect(repository.savedDrafts, hasLength(1));
    expect(repository.savedDrafts.single.single['coreId'], 'CORE-1');
    expect(repository.savedDrafts.single.single['assignedUserId'], 'EMP-1');
    expect(
      repository.savedDrafts.single.single['jobDescription'],
      'Painting Door RH',
    );
  });

  testWidgets('JobPlanList filters locally and keeps Jobdesc label', (
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
    expect(repository.calls.single['divisionId'], isNull);
    expect(repository.calls.single['unitId'], isNull);
    expect(repository.calls.single['employeeId'], isNull);
    expect(repository.optionCalls, 0);
    expect(find.text('Tanggal'), findsOneWidget);
    expect(find.text('Divisi'), findsOneWidget);
    expect(find.text('Unit'), findsOneWidget);
    expect(find.text('PIC'), findsOneWidget);
    expect(find.textContaining('Jobdesc: Painting Door RH'), findsOneWidget);
  });
}
