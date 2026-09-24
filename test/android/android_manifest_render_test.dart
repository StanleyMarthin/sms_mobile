/*
Tujuan: Mengunci manifest Android agar tidak memaksa Flutter keluar dari render engine default.
Caller: Flutter test runner.
Dependensi: android/app/src/main/AndroidManifest.xml.
Main Functions: main().
Side Effects: Membaca file manifest dari repo.
*/

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest does not disable Impeller rendering', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      isNot(contains('io.flutter.embedding.android.EnableImpeller')),
    );
    expect(manifest, isNot(contains('android:value="false"')));
  });
}
