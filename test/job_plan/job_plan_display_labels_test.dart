/*
Tujuan: Mengunci label approval Job Plan agar ADV tampil sebagai QA tanpa mengubah status teknis.
Caller: flutter test.
Dependensi: flutter_test, filesystem source.
Main Functions: test label literals.
Side Effects: Tidak ada; hanya assertion.
*/
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('job plan displays QA label for pending ADV status', () {
    final source = File(
      'lib/features/job_plan/presentation/pages/job_plan_page.dart',
    ).readAsStringSync();

    expect(source, contains("'PENDING_ADV' => 'Menunggu QA'"));
    expect(source, contains("'PENDING_ADV' => 'QA'"));
    expect(source, isNot(contains("'PENDING_ADV' => 'Menunggu Advisor'")));
    expect(source, isNot(contains("'PENDING_ADV' => 'ADV'")));
  });
}
