/*
Tujuan: Helper pesan aman dan sinyal refresh untuk konflik command Job Plan.
Caller: Page mutation Job Plan dan unit test.
Dependensi: DioException, Failure, ApiClient, friendlyMessage.
Main Functions: JobPlanCommandFeedback.
Side Effects: Tidak ada.
*/
library;

import 'package:dio/dio.dart';
import 'package:sm_system/core/errors/error_message.dart';
import 'package:sm_system/core/errors/failures.dart';
import 'package:sm_system/core/network/api_client.dart';

abstract class JobPlanCommandFeedback {
  static bool shouldRefresh(Object error) {
    final code = _code(error);
    return {
      'ERR_STALE_PLAN',
      'ERR_IDEMPOTENCY_CONFLICT',
      'ERR_INVALID_TRANSITION',
      'ERR_EMPLOYEE_ALREADY_RUNNING',
    }.contains(code);
  }

  static String message(Object error) {
    return switch (_code(error)) {
      'ERR_STALE_PLAN' => 'Data Job Plan berubah. Memuat ulang data terbaru.',
      'ERR_IDEMPOTENCY_CONFLICT' =>
        'Command ID sudah dipakai untuk data berbeda.',
      'ERR_INVALID_TRANSITION' =>
        'Status Job Plan sudah berubah. Memuat ulang data terbaru.',
      'ERR_EMPLOYEE_ALREADY_RUNNING' =>
        'PIC masih menjalankan pekerjaan lain. Memuat ulang jadwal terbaru.',
      _ => friendlyMessage(error, fallback: 'Gagal memproses Job Plan'),
    };
  }

  static String? _code(Object error) {
    if (error is Failure) return error.errorCode;
    if (error is DioException) {
      final mapped = ApiClient.mapDioError(error);
      return mapped.errorCode;
    }
    return null;
  }
}
