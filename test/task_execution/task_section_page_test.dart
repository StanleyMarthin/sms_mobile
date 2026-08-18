/*
Tujuan: Memastikan routing mode task membedakan anggota, kepala divisi, dan manajemen lain.
Caller: Flutter test runner.
Dependensi: TaskSectionPage.
Main Functions: main.
Side Effects: Tidak ada.
*/
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/features/task_execution/presentation/pages/task_section_page.dart';

void main() {
  test('anggota langsung masuk mode PIC', () {
    expect(
      resolveTaskSectionPresentation(isOperator: true, isKd: false),
      TaskSectionPresentation.pic,
    );
  });

  test('kepala divisi mendapat pilihan monitoring dan PIC', () {
    expect(
      resolveTaskSectionPresentation(isOperator: false, isKd: true),
      TaskSectionPresentation.kdModes,
    );
  });

  test('kepala divisi tetap mendapat mode PIC saat punya akses eksekusi', () {
    expect(
      resolveTaskSectionPresentation(isOperator: true, isKd: true),
      TaskSectionPresentation.kdModes,
    );
  });

  test('manajemen selain kepala divisi tetap masuk monitoring', () {
    expect(
      resolveTaskSectionPresentation(isOperator: false, isKd: false),
      TaskSectionPresentation.monitoring,
    );
  });
}
