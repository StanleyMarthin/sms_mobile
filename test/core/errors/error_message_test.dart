/*
Tujuan: Memverifikasi friendlyMessage menghasilkan pesan manusiawi.
Caller: Flutter test suite untuk core errors.
Dependensi: error_message.dart, failures.dart, dio, flutter_test.
Main Functions: main().
Side Effects: Tidak ada.
*/

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sm_system/core/errors/error_message.dart';
import 'package:sm_system/core/errors/failures.dart';

void main() {
  group('friendlyMessage', () {
    test('memakai pesan Failure yang sudah manusiawi', () {
      expect(friendlyMessage(const NetworkFailure()), contains('izin istirahat'));
      expect(friendlyMessage(const TimeoutFailure()), contains('ngos-ngosan'));
      expect(friendlyMessage(const ServerFailure()), contains('Servernya lagi capek'));
      expect(friendlyMessage(const DataParsingFailure()), contains('server'));
    });

    test('memetakan DioException tanpa membocorkan detail teknis', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/api/test'),
        type: DioExceptionType.connectionError,
        message: 'SocketException: failed to connect',
      );
      expect(friendlyMessage(error), contains('izin istirahat'));
      expect(friendlyMessage(error), isNot(contains('SocketException')));
    });

    test('menggunakan fallback untuk error tak dikenal', () {
      expect(
        friendlyMessage(
          Exception('stack trace internal'),
          fallback: 'Gagal memuat PR',
        ),
        'Gagal memuat PR',
      );
    });
  });
}
