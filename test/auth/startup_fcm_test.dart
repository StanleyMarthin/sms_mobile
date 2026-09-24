/*
Tujuan: Mengunci helper startup FCM agar error permission tetap ditangani tanpa memblokir render awal.
Caller: Flutter test runner.
Dependensi: main.dart initFcmOrExit().
Main Functions: main().
Side Effects: Tidak ada; init/exit memakai closure in-memory.
*/

import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/main.dart' as app;

void main() {
  test('initFcmOrExit ignores successful notification init', () async {
    var initialized = false;
    var exited = false;

    await app.initFcmOrExit(
      init: () async => initialized = true,
      exit: () async => exited = true,
    );

    expect(initialized, isTrue);
    expect(exited, isFalse);
  });

  test('initFcmOrExit exits only on denied notification permission', () async {
    var exited = false;

    await app.initFcmOrExit(
      init: () => Future<void>.error('NOTIFICATION_PERMISSION_DENIED'),
      exit: () async => exited = true,
    );

    expect(exited, isTrue);
  });
}
