/*
Tujuan: Mengunci satu entry point Job Plan dan kompatibilitas deep link lama.
Caller: Flutter test runner.
Dependensi: JobPlanNavigation.
Main Functions: main.
Side Effects: Tidak ada.
*/
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/job_plan/presentation/utils/job_plan_navigation.dart';

void main() {
  test('old list route redirects to the main page preserving filters', () {
    expect(
      JobPlanNavigation.redirect(
        Uri.parse('/job-plans/v2?unitId=U1&date=2026-09-20'),
      ),
      '/plans?unitId=U1&date=2026-09-20&tab=status',
    );
  });
  test('old command route keeps its core identity', () {
    expect(
      JobPlanNavigation.redirect(Uri.parse('/job-plans/v2/create?coreId=CD-1')),
      '/plans/create?coreId=CD-1',
    );
    expect(JobPlanNavigation.redirect(Uri.parse('/plans')), isNull);
    expect(JobPlanNavigation.redirect(Uri.parse('/qc/v2')), isNull);
  });
}
